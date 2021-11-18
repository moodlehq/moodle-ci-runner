#!/bin/bash
#
# This file is part of the Moodle Continous Integration Project.
#
# Moodle is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Moodle is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Moodle.  If not, see <http://www.gnu.org/licenses/>.

set -u
set -o pipefail

SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CACHEDIR="${CACHEDIR:-${HOME}/caches}"
export COMPOSERCACHE="${COMPOSERCACHE:-${CACHEDIR}/composer}"
export CODEDIR="${CODEDIR:-${WORKSPACE}/moodle}"
export OUTPUTDIR="${WORKSPACE}"/"${BUILD_ID}"
export ENVIROPATH="${OUTPUTDIR}"/environment.list
# The PLUGINSTOINSTALL variable could be set to install external plugins in the CODEDIR folder. The following information is needed
# for each plugin: gitrepo, folder and branch (optional). The plugin fields should be separated by "|" and each plugin should
# be separated using ";": "gitrepoplugin1|gitfolderplugin1|gitbranchplugin1;gitrepoplugin2|gitfolderplugin2|gitbranchplugin2[...]"
# Example: "https://github.com/moodlehq/moodle-local_mobile.git|local/mobile|MOODLE_37_STABLE;git@github.com:jleyva/moodle-block_configurablereports.git|blocks/configurable_reports"
export PLUGINSTOINSTALL="${PLUGINSTOINSTALL:-}"
# Plugin folder where the plugins to install will be downloaded.
export PLUGINSDIR="${PLUGINSDIR:-${WORKSPACE}/plugins}"

mkdir -p "${PLUGINSDIR}"
if [ -n "$PLUGINSTOINSTALL" ];
then
  echo ">>> startsection Download external plugins <<<"
  echo "============================================================================"
  # Download all the plugins in a temporary folder.
  IFS=';' read -ra PLUGINS <<< "$PLUGINSTOINSTALL"
  for PLUGIN in "${PLUGINS[@]}";
  do
    if  [ -n "$PLUGIN" ]
    then
      PLUGINGITREPO=$(echo "$PLUGIN" | cut -f1 -d'|')
      PLUGINFOLDER=$(echo "$PLUGIN" | cut -f2 -d'|')
      PLUGINBRANCH=$(echo "$PLUGIN" | cut -f3 -d'|')
      echo "Cloning ${PLUGINGITREPO}/${PLUGINBRANCH}"

      if [ -n "${PLUGINBRANCH}" ]
      then
        # Only download this branch.
        PLUGINBRANCH="-b ${PLUGINBRANCH} --single-branch"
      fi

      # Clone the plugin repository in the defined folder.
      git clone ${PLUGINBRANCH} ${PLUGINGITREPO} "${PLUGINSDIR}/${PLUGINFOLDER}"
      echo "Cloned. HEAD is @ $(cd "${PLUGINSDIR}/${PLUGINFOLDER}" && git rev-parse HEAD)"
      echo
    fi
  done
  unset IFS
  echo "============================================================================"
  echo ">>> stopsection <<<"
  echo
fi

# Which PHP Image to use.
export PHP_VERSION="${PHP_VERSION:-7.1}"
export PHP_SERVER_DOCKER="${PHP_SERVER_DOCKER:-moodlehq/moodle-php-apache:${PHP_VERSION}}"

# Which Moodle version (XY) is being used.
export MOODLE_VERSION=$(grep "\$branch" "${CODEDIR}"/version.php | sed "s/';.*//" | sed "s/^\$.*'//")
# Which Mobile app version is used: latest (stable), next (master), x.y.z.
# If the MOBILE_VERSION is not defined, the moodlemobile docker won't be executed.
export MOBILE_VERSION="${MOBILE_VERSION:-}"
export MOBILE_APP_PORT="${MOBILE_APP_PORT:-8100}"

# Default type of test to run.
# phpunit or behat.
export TESTTORUN="${TESTTORUN:-phpunit}"

# Default DB settings.
# Todo: Tidy this up properly.
export DBTYPE="${DBTYPE:-pgsql}"
export DBTORUN="${DBTORUN:-}"
export DBSLAVES="${DBSLAVES:-0}"

# Test defaults
export BROWSER="${BROWSER:-chrome}"
export BROWSER_DEBUG="${BROWSER_DEBUG:-}"
export BROWSER_HEADLESS="${BROWSER_HEADLESS:-}"
export DISABLE_MARIONETTE=
export BEHAT_SUITE="${BEHAT_SUITE:-}"
export BEHAT_TOTAL_RUNS="${BEHAT_TOTAL_RUNS:-3}"
export BEHAT_NUM_RERUNS="${BEHAT_NUM_RERUNS:-1}"
export TAGS="${TAGS:-}"
export NAME="${NAME:-}"
export TESTSUITE="${TESTSUITE:-}"
export RUNCOUNT="${RUNCOUNT:-1}"
export BEHAT_TIMING_FILENAME="${BEHAT_TIMING_FILENAME:-}"
export BEHAT_INCREASE_TIMEOUT="${BEHAT_INCREASE_TIMEOUT:-}"

# Remove some stuff that, simply, cannot be there based on $TESTTORUN
if [ "${TESTTORUN}" == "phpunit" ]
then
    BROWSER=
    BEHAT_SUITE=
    BEHAT_TOTAL_RUNS=
    BEHAT_NUM_RERUNS=
    BEHAT_TIMING_FILENAME=
    BEHAT_INCREASE_TIMEOUT=
elif [ "${TESTTORUN}" == "behat" ]
then
    TESTSUITE=

    # If the composer.json contains instaclick then we must disable marionette and use an older version of firefox.
    hasinstaclick=$((`grep instaclick "${CODEDIR}"/composer.json | wc -l`))
    if [[ ${hasinstaclick} -ge 1 ]]
    then
        export DISABLE_MARIONETTE=1
    fi
fi

# Ensure that the output directory exists.
# It must also be set with the sticky bit, and world writable.
# Apache and Behat run as www-data, and must be able to write to this directory, but there is no reliabel UID mapping
# between the container and host.
mkdir -p "${OUTPUTDIR}"

rm -f "${ENVIROPATH}"
touch "${ENVIROPATH}"

if [ ! -z "$BEHAT_TIMING_FILENAME" ]
then
  mkdir -p "${WORKSPACE}/timing"
  TIMINGSOURCE="${WORKSPACE}/timing/${BEHAT_TIMING_FILENAME}"

  if [ -f "${TIMINGSOURCE}" ]
  then
    cp "${TIMINGSOURCE}" "${OUTPUTDIR}"/timing.json
  else
    touch "${OUTPUTDIR}"/timing.json
  fi
fi

chmod -R g+sw,a+sw "${OUTPUTDIR}"

# Select db to use today.
if [ -n "$DBTORUN" ]
then
  DBTORUN=(`echo ${DBTORUN}`);
  # Find which db to run today.
  dayoftheweek=`date +"%u"`
  if [[ -z ${DBTORUN} ]]; then
    DBTYPE=pgsql
  else
    DBTYPE=${DBTORUN[ $(( ${dayoftheweek} - 1 )) ]}
  fi
  echo "Running against ${DBTYPE}"
fi

# Setup Environment
UUID=$(uuid | sha1sum | awk '{print $1}')
UUID=${UUID:0:16}
export DBHOST=database"${UUID}"
export DBTYPE="${DBTYPE:-pgsql}"
export DBUSER="${DBUSER:-moodle}"
export DBPASS="${DBPASS:-moodle}"
export DBHOST="${DBHOST:-${DBTYPE}}"
export DBHOST_SLAVE=""
export DBNAME="moodle"

echo "DBTYPE" >> "${ENVIROPATH}"
echo "DBSLAVES" >> "${ENVIROPATH}"
echo "DBHOST" >> "${ENVIROPATH}"
echo "DBHOST_SLAVE" >> "${ENVIROPATH}"
echo "DBUSER" >> "${ENVIROPATH}"
echo "DBPASS" >> "${ENVIROPATH}"
echo "DBNAME" >> "${ENVIROPATH}"
echo "DBCOLLATION" >> "${ENVIROPATH}"
echo "BROWSER" >> "${ENVIROPATH}"
echo "BROWSER_DEBUG" >> "${ENVIROPATH}"
echo "BROWSER_HEADLESS" >> "${ENVIROPATH}"
echo "WEBSERVER" >> "${ENVIROPATH}"
echo "BEHAT_TOTAL_RUNS" >> "${ENVIROPATH}"
echo "BEHAT_NUM_RERUNS" >> "${ENVIROPATH}"
echo "BEHAT_TIMING_FILENAME" >> "${ENVIROPATH}"
echo "BEHAT_INCREASE_TIMEOUT" >> "${ENVIROPATH}"
echo "DISABLE_MARIONETTE" >> "${ENVIROPATH}"

echo "============================================================================"
echo "= Job summary <<<"
echo "============================================================================"
echo "== Workspace: ${WORKSPACE}"
echo "== Build Id: ${BUILD_ID}"
echo "== Output directory: ${OUTPUTDIR}"
echo "== UUID: ${UUID}"
echo "== Container prefix: ${UUID}"
echo "== PHP Version: ${PHP_VERSION}"
echo "== DBTORUN: ${DBTORUN}"
echo "== DBTYPE: ${DBTYPE}"
echo "== DBSLAVES: ${DBSLAVES}"
echo "== TESTTORUN: ${TESTTORUN}"
echo "== BROWSER: ${BROWSER}"
echo "== BROWSER_DEBUG: ${BROWSER_DEBUG}"
echo "== BROWSER_HEADLESS: ${BROWSER_HEADLESS}"
echo "== DISABLE_MARIONETTE: ${DISABLE_MARIONETTE}"
echo "== RUNCOUNT: ${RUNCOUNT}"
echo "== BEHAT_TOTAL_RUNS: ${BEHAT_TOTAL_RUNS}"
echo "== BEHAT_NUM_RERUNS: ${BEHAT_NUM_RERUNS}"
echo "== BEHAT_INCREASE_TIMEOUT: ${BEHAT_INCREASE_TIMEOUT}"
echo "== BEHAT_SUITE: ${BEHAT_SUITE}"
echo "== TAGS: ${TAGS}"
echo "== NAME: ${NAME}"
echo "== MOBILE_APP_PORT: ${MOBILE_APP_PORT}"
echo "== MOBILE_VERSION: ${MOBILE_VERSION}"
echo "== PLUGINSTOINSTALL: ${PLUGINSTOINSTALL}"
echo "== TESTSUITE: ${TESTSUITE}"
echo "== Environment: ${ENVIROPATH}"
echo "============================================================================"

# Setup the image cleanup.
function finish {
  echo
  echo ">>> startsection Cleaning up docker images <<<"
  echo "============================================================================"
  echo "Stopping all docker images for ${UUID}"
  docker ps -a --filter name=${UUID}
  for image in `docker ps -a -q --filter name=${UUID}`
  do
      docker stop $image
  done
  echo "============================================================================"
  echo ">>> stopsection <<<"
}
trap finish EXIT

function ctrl_c() {
  echo
  echo "============================================================================"
  echo "Job was cancelled at user request"
  echo "============================================================================"
  exit 255
}
trap ctrl_c INT

echo
echo ">>> startsection Checking networks <<<"
echo "============================================================================"
NETWORKNAME="${NETWORKNAME:-moodle}"
NETWORK=$(docker network list -q --filter name="${NETWORKNAME}$")
if [[ -z ${NETWORK} ]]
then
    echo "Creating new network '${NETWORKNAME}'"
    NETWORK=$(docker network create "${NETWORKNAME}")
fi
echo "Found network '${NETWORKNAME}' with  identifier ${NETWORK}"
echo "============================================================================"
echo ">>> stopsection <<<"

echo
echo ">>> startsection Starting database server <<<"
echo "============================================================================"

if [ "${DBTYPE}" == "mysqli" ]
then

  if [ "${DBSLAVES}" -ne 0 ]
  then
    export DBHOST_SLAVE="${DBHOST}_slave"

    echo "Starting master"
    docker run \
      --detach \
      --name ${DBHOST} \
      --network "${NETWORK}" \
      -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
      -e MYSQL_DATABASE="${DBNAME}" \
      -e MYSQL_USER="${DBUSER}" \
      -e MYSQL_PASSWORD="${DBPASS}" \
      -e DBHOST_SLAVE=$DBHOST_SLAVE \
      --tmpfs /var/lib/mysql:rw \
      -v $SCRIPTPATH/mysql.d/master/conf.d:/etc/mysql/conf.d \
      -v $SCRIPTPATH/mysql.d/master/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d \
      mysql:5

    echo "Starting slave"
    docker run \
      --detach \
      --name ${DBHOST_SLAVE} \
      --network "${NETWORK}" \
      -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
      -e MYSQL_DATABASE="${DBNAME}" \
      -e MYSQL_USER="${DBUSER}" \
      -e MYSQL_PASSWORD="${DBPASS}" \
      -e DBHOST=$DBHOST \
      -e DBHOST_SLAVE=$DBHOST_SLAVE \
      -v $SCRIPTPATH/mysql.d/slave/config:/config \
      -v $SCRIPTPATH/mysql.d/slave/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d \
      --tmpfs /var/lib/mysql:rw \
      mysql:5

    # Hack to make gosu work for all users on the slave.
    docker exec -u root $DBHOST_SLAVE bash -c 'chown root:mysql /usr/local/bin/gosu'
    docker exec -u root $DBHOST_SLAVE bash -c 'chmod +s /usr/local/bin/gosu'
  else
    echo "Starting standalone"
    docker run \
      --detach \
      --name ${DBHOST} \
      --network "${NETWORK}" \
      -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
      -e MYSQL_DATABASE="${DBNAME}" \
      -e MYSQL_USER="${DBUSER}" \
      -e MYSQL_PASSWORD="${DBPASS}" \
      --tmpfs /var/lib/mysql:rw \
      -v $SCRIPTPATH/mysql.d/standalone/conf.d:/etc/mysql/conf.d \
      mysql:5
  fi

  export DBCOLLATION=utf8mb4_bin

  # Wait few sec, before executing commands.
  sleep 20

elif [ "${DBTYPE}" == "mariadb" ]
then
  if [ "${DBSLAVES}" != "0" ]
  then
    export DBHOST_SLAVE="${DBHOST}_slave"

    echo "Starting master"
    docker run \
      --detach \
      --name ${DBHOST} \
      --network "${NETWORK}" \
      -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
      -e MYSQL_DATABASE="${DBNAME}" \
      -e MYSQL_USER="${DBUSER}" \
      -e MYSQL_PASSWORD="${DBPASS}" \
      -e DBHOST_SLAVE=$DBHOST_SLAVE \
      --tmpfs /var/lib/mysql:rw \
      -v $SCRIPTPATH/mysql.d/master/conf.d:/etc/mysql/conf.d \
      -v $SCRIPTPATH/mysql.d/master/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d \
      mariadb:10.5

    echo "Starting slave"
    docker run \
      --detach \
      --name ${DBHOST_SLAVE} \
      --network "${NETWORK}" \
      -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
      -e MYSQL_DATABASE="${DBNAME}" \
      -e MYSQL_USER="${DBUSER}" \
      -e MYSQL_PASSWORD="${DBPASS}" \
      -e DBHOST=$DBHOST \
      -e DBHOST_SLAVE=$DBHOST_SLAVE \
      -v $SCRIPTPATH/mysql.d/slave/config:/config \
      -v $SCRIPTPATH/mysql.d/slave/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d \
      --tmpfs /var/lib/mysql:rw \
      mariadb:10.5

    # Hack to make gosu work for all users on the slave.
    docker exec -u root $DBHOST_SLAVE bash -c 'chown root:mysql /usr/local/bin/gosu'
    docker exec -u root $DBHOST_SLAVE bash -c 'chmod +s /usr/local/bin/gosu'
  else
    echo "Starting standalone"
    docker run \
      --detach \
      --name ${DBHOST} \
      --network "${NETWORK}" \
      -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
      -e MYSQL_DATABASE="${DBNAME}" \
      -e MYSQL_USER="${DBUSER}" \
      -e MYSQL_PASSWORD="${DBPASS}" \
      --tmpfs /var/lib/mysql:rw \
      -v $SCRIPTPATH/mysql.d/standalone/conf.d:/etc/mysql/conf.d \
      mariadb:10.5
  fi

  export DBCOLLATION=utf8mb4_bin

  # Wait few sec, before executing commands.
  sleep 20

elif [ "${DBTYPE}" == "oci" ]
then
  docker run \
    --detach \
    --name ${DBHOST} \
    --network "${NETWORK}" \
    -v $SCRIPTPATH/oracle.d/tmpfs.sh:/docker-entrypoint-initdb.d/tmpfs.sh \
    --tmpfs /var/lib/oracle \
    --shm-size=2g \
    -e ORACLE_DISABLE_ASYNCH_IO=true \
    moodlehq/moodle-db-oracle-r2

  # Wait few sec, before executing commands.
  sleep 140

  export DBPASS="m@0dl3ing"
  export DBNAME="XE"

elif [ "${DBTYPE}" == "mssql" ] || [ "${DBTYPE}" == "sqlsrv" ]
then

  export DBUSER="sa"
  export DBPASS="Passw0rd!"

  docker run \
    --detach \
    --name ${DBHOST} \
    --network "${NETWORK}" \
    -e ACCEPT_EULA=Y \
    -e SA_PASSWORD="${DBPASS}" \
    moodlehq/moodle-db-mssql:2017-latest

  # Wait few sec, before executing commands.
  sleep 10

elif [ "${DBTYPE}" == "pgsql" ]
then
  if [ "${DBSLAVES}" -ne 0 ]
  then
    export DBHOST_SLAVE="${DBHOST}_slave"
  fi

  docker run \
    --detach \
    --name ${DBHOST} \
    --network "${NETWORK}" \
    -e POSTGRES_USER=moodle \
    -e POSTGRES_PASSWORD=moodle \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -e POSTGRES_DB=initial \
    -e DBHOST_SLAVE=$DBHOST_SLAVE \
    -e DBNAME=$DBNAME \
    -v $SCRIPTPATH/pgsql.d:/docker-entrypoint-initdb.d \
    --tmpfs /var/lib/postgresql/data:rw \
    postgres:10

  # Wait few sec, before executing commands.
  sleep 10

  if [ "${DBSLAVES}" -ne 0 ]
  then
    echo "Starting slave"
    docker run \
      --detach \
      --name ${DBHOST_SLAVE} \
      --network "${NETWORK}" \
      -e POSTGRES_USER=moodle \
      -e POSTGRES_PASSWORD=moodle \
      -e POSTGRES_HOST_AUTH_METHOD=trust \
      -e POSTGRES_DB=initial \
      -e DBHOST=$DBHOST \
      -e DBHOST_SLAVE=$DBHOST_SLAVE \
      -e DBNAME=$DBNAME \
      -v $SCRIPTPATH/pgsql.d:/docker-entrypoint-initdb.d \
      --tmpfs /var/lib/postgresql/data:rw \
      postgres:10

    # Hack to make gosu work for all users on the slave.
    docker exec -u root $DBHOST_SLAVE bash -c 'chown root:postgres /usr/local/bin/gosu'
    docker exec -u root $DBHOST_SLAVE bash -c 'chmod +s /usr/local/bin/gosu'
  fi

  # Wait few sec, before executing commands for all nodes to come up.
  sleep 10

else

  echo "Unknown database type ${DBTYPE}"
  exit 255

fi

echo "============================================================================"
echo ">>> stopsection <<<"

echo
echo ">>> startsection Database summary <<<"
echo "============================================================================"
echo "== DBTORUN: ${DBTORUN}"
echo "== DBTYPE: ${DBTYPE}"
echo "== DBHOST: ${DBHOST}"
echo "== DBHOST_SLAVE: ${DBHOST_SLAVE}"
echo "== DBUSER: ${DBUSER}"
echo "== DBPASS: ${DBPASS}"
echo "== DBNAME: ${DBNAME}"

docker logs "${DBHOST}"

if [ "${DBHOST_SLAVE}" != "" ]
then
  echo
  echo ">>> startsection Database slave summary <<<"
  echo "============================================================================"
  docker logs "${DBHOST_SLAVE}"
  echo "============================================================================"
  echo ">>> stopsection <<<"
fi

echo "============================================================================"
echo ">>> stopsection <<<"


echo
echo ">>> startsection Starting supplemental services <<<"
echo "============================================================================"
BBBMOCK=bbbmock"${UUID}"
docker run \
  --detach \
  --name ${BBBMOCK} \
  --network "${NETWORK}" \
  moodlehq/bigbluebutton_mock:latest

export BBBMOCKURL="http://${BBBMOCK}"
echo BBBMOCKURL >> "${ENVIROPATH}"
docker logs ${BBBMOCK}


if [ "${TESTTORUN}" == "phpunit" ]
then
  EXTTESTNAME=exttests"${UUID}"

  docker run \
    --detach \
    --name ${EXTTESTNAME} \
    --network "${NETWORK}" \
    moodlehq/moodle-exttests:latest

  export EXTTESTURL="http://${EXTTESTNAME}"
  echo EXTTESTURL >> "${ENVIROPATH}"
  docker logs ${EXTTESTNAME}


  LDAPTESTNAME=ldap"${UUID}"

  docker run \
    --detach \
    --name ${LDAPTESTNAME} \
    --network "${NETWORK}" \
    larrycai/openldap

  export LDAPTESTURL="ldap://${LDAPTESTNAME}"
  echo LDAPTESTURL >> "${ENVIROPATH}"
  docker logs ${LDAPTESTNAME}


  export SOLRTESTNAME=solr"${UUID}"
  docker run \
    --detach \
    --name ${SOLRTESTNAME} \
    --network "${NETWORK}" \
    solr:7 \
    solr-precreate test

  echo SOLRTESTNAME >> "${ENVIROPATH}"
  docker logs ${SOLRTESTNAME}


  export REDISTESTNAME=redis"${UUID}"
  docker run \
    --detach \
    --name ${REDISTESTNAME} \
    --network "${NETWORK}" \
    redis:3

  echo REDISTESTNAME >> "${ENVIROPATH}"
  docker logs ${REDISTESTNAME}


  MEMCACHED1TESTNAME=memcached1"${UUID}"
  docker run \
    --detach \
    --name ${MEMCACHED1TESTNAME} \
    --network "${NETWORK}" \
    memcached:1.4

  export MEMCACHED1TESTURL="${MEMCACHED1TESTNAME}:11211"
  echo MEMCACHED1TESTURL >> "${ENVIROPATH}"
  docker logs ${MEMCACHED1TESTNAME}


  MEMCACHED2TESTNAME=memcached2"${UUID}"
  docker run \
    --detach \
    --name ${MEMCACHED2TESTNAME} \
    --network "${NETWORK}" \
    memcached:1.4

  export MEMCACHED2TESTURL="${MEMCACHED2TESTNAME}:11211"
  echo MEMCACHED2TESTURL >> "${ENVIROPATH}"
  docker logs ${MEMCACHED2TESTNAME}


  MONGODBTESTNAME=mongodb"${UUID}"
  docker run \
    --detach \
    --name ${MONGODBTESTNAME} \
    --network "${NETWORK}" \
    mongo:4.0

  export MONGODBTESTURL="mongodb://${MONGODBTESTNAME}:27017"
  echo MONGODBTESTURL >> "${ENVIROPATH}"
  docker logs ${MONGODBTESTNAME}
fi

echo "============================================================================"
echo ">>> stopsection <<<"

if [ "$TESTTORUN" == "behat" ]
then
  echo
  echo ">>> startsection Starting selenium server <<<"
  echo "============================================================================"

  SHMMAP="--shm-size=2g"

  HASSELENIUM=1
  SELVERSION="3.141.59"
  # We are going brave here and go back to unpinned chrome version, because staying with
  # the old Chrome 79 version (3.141.59-zinc) is making things really harder and harder.
  # We are aware that, for headed runs, there are some zero-size errors still not fixed,
  # but headless ones should run ok. For reference, the problems we are aware are being
  # tracked (as of 14 Sep 2021) @:
  #   - MDL-71108 : zero-size
  #   - MDL-72306 : feedback
  SELCHROMEIMAGE="selenium/standalone-chrome:${SELVERSION}"
  SELFIREFOXIMAGE="selenium/standalone-firefox:${SELVERSION}"

  # Temporarily switching to custom image to include our bugfix for zero size failures.
  SELCHROMEIMAGE="moodlehq/selenium-standalone-chrome:3.141.59-20210929-moodlehq"

  # Newer versions of Firefox do not allow Marionette to be disabled.
  # Version 47.0.1 is the latest version of Firefox we can support when Marionette is disabled.
  if [[ ${DISABLE_MARIONETTE} -ge 1 ]]
  then
      SELFIREFOXIMAGE="moodlehq/moodle-standalone-firefox:3.141.59_47.0.1"
  fi


  if [ "$BROWSER" == "chrome" ]
  then

    if [ ! -z "$MOBILE_VERSION" ] && [ -d "${PLUGINSDIR}/local/moodlemobileapp" ]
    then
      # Only run the moodlemobile docker container when the MOBILE_VERSION is defined.
      IONICHOSTNAME="ionic${UUID}"
      echo $IONICHOSTNAME

      docker run \
        --network "${NETWORK}" \
        --name ${IONICHOSTNAME} \
        --detach \
        moodlehq/moodleapp:"${MOBILE_VERSION}"

      export "IONICURL"="http://${IONICHOSTNAME}:${MOBILE_APP_PORT}"
      echo "IONICURL" >> "${ENVIROPATH}"
    fi

    ITER=1
    while [[ ${ITER} -le ${BEHAT_TOTAL_RUNS} ]]
    do
      SELITERNAME=selenium"${ITER}${UUID}"
      docker run \
        --network "${NETWORK}" \
        --name ${SELITERNAME} \
        --detach \
        $SHMMAP \
        -v "${CODEDIR}":/var/www/html \
        ${SELCHROMEIMAGE}

      export "SELENIUMURL_${ITER}"="http://${SELITERNAME}:4444"
      echo "SELENIUMURL_${ITER}" >> "${ENVIROPATH}"

      ITER=$(($ITER+1))
    done
  elif [ "$BROWSER" == "firefox" ]
  then

    ITER=1
    while [[ ${ITER} -le ${BEHAT_TOTAL_RUNS} ]]
    do
      SELITERNAME=selenium"${ITER}${UUID}"
      docker run \
        --network "${NETWORK}" \
        --name ${SELITERNAME} \
        --detach \
        $SHMMAP \
        -v "${CODEDIR}":/var/www/html \
        ${SELFIREFOXIMAGE}

      export "SELENIUMURL_${ITER}"="http://${SELITERNAME}:4444"
      echo "SELENIUMURL_${ITER}" >> "${ENVIROPATH}"

      ITER=$(($ITER+1))
    done
  elif [ "$BROWSER" == "goutte" ]
  then
      export BROWSER=""
      HASSELENIUM=0
      echo "No selenium server required"
  fi

  if [ "${HASSELENIUM}" -gt 0 ]
  then
      sleep 5

      ITER=1
      while [[ ${ITER} -le ${BEHAT_TOTAL_RUNS} ]]
      do
        docker logs selenium"${ITER}${UUID}"
        ITER=$(($ITER+1))
      done
  fi

  echo "============================================================================"
  echo ">>> stopsection <<<"
fi

# Start the test server.
echo
echo ">>> startsection Starting web server <<<"
echo "============================================================================"
export WEBSERVER=webserver"${UUID}"
docker run \
  --network "${NETWORK}" \
  --name "${WEBSERVER}" \
  --detach \
  --env-file "${ENVIROPATH}" \
  -v "${COMPOSERCACHE}:/var/www/.composer:rw" \
  -v "${OUTPUTDIR}":/shared \
  ${PHP_SERVER_DOCKER}

# Copy code in place.
echo "== Copying code in place"
docker cp "${CODEDIR}"/. "${WEBSERVER}":/var/www/html
if [ -n "$PLUGINSTOINSTALL" ];
then
  echo "== Copying external plugins in place"
  docker cp "${PLUGINSDIR}"/. "${WEBSERVER}":/var/www/html
fi

# Copy the config.php in place
echo "== Copying configuration"
docker cp "${SCRIPTPATH}/config.template.php" "${WEBSERVER}":/var/www/html/config.php

COMPOSERPHAR="${COMPOSERCACHE}/composer.phar"
if [ -f "${COMPOSERPHAR}" ]
then
  docker cp "${COMPOSERPHAR}" "${WEBSERVER}":/var/www/html/composer.phar
  docker exec -t "${WEBSERVER}" bash -c 'chown -R www-data:www-data /var/www/html/composer.phar'
fi

echo "============================================================================"
docker logs "${WEBSERVER}"
echo "============================================================================"
echo ">>> stopsection <<<"

echo
echo ">>> startsection Waiting for all containers to become healthy<<<"
echo "============================================================================"
for waitperiod in {0..90}
do
  # Note we cannot use the 'health' filter due to https://github.com/moby/moby/issues/35920
  startingcount=$((`docker ps -a --filter name=${UUID} | grep -e starting -e unhealthy | wc -l`))
  if [[ ${startingcount} -lt 1 ]]
  then
    break
  fi
  echo "Waiting for ${startingcount} containers to become healthy"
  sleep 1
done
startingcount=$((`docker ps -a --filter name=${UUID} | grep -e starting -e unhealthy | wc -l`))
if [[ ${startingcount} -gt 0 ]]
then
  echo "Some containers were too slow. Aborting the run:"
  docker ps -a --filter name=${UUID} --filter | grep -e starting -e unhealthy
  exit 1
fi
echo "All containers started"

echo "============================================================================"
echo ">>> stopsection <<<"

# Prepare the summary of images being used by the run (creation date & digest)
echo
echo ">>> startsection Details about the images being used by the run<<<"
echo "============================================================================"
docker ps --filter "name=${UUID}" --format='{{.Image}}' | sort | uniq | xargs -I{} \
    docker image inspect \
        --format '{} {{if .Created}}created:{{.Created}}{{end}} {{if .RepoDigests}}{{index .RepoDigests 0}}{{end}}' {} | \
    tr '@' ' ' | cut -f1,2,4 -d' '

echo "============================================================================"
echo ">>> stopsection <<<"

# Setup the DB.
echo
echo ">>> startsection Initialising test environment<<<"
echo "============================================================================"
if [ "$TESTTORUN" == "behat" ]
then
  BEHAT_INIT_SUITE=""
  BEHAT_RUN_SUITE=""
  if [ -n "$BEHAT_SUITE" ]
  then
    BEHAT_INIT_SUITE="-a=${BEHAT_SUITE}"
    if [ "${BEHAT_SUITE}" != "ALL" ]
    then
      BEHAT_RUN_SUITE="--suite=${BEHAT_SUITE}"
    fi
  fi

  echo php admin/tool/behat/cli/init.php \
      ${BEHAT_INIT_SUITE} \
      --axe \
      -j="${BEHAT_TOTAL_RUNS}"

  docker exec -t "${WEBSERVER}" bash -c 'chown -R www-data:www-data /var/www/*'

  docker exec -t -u www-data "${WEBSERVER}" \
    php admin/tool/behat/cli/init.php \
      ${BEHAT_INIT_SUITE} \
      --axe \
      -j="${BEHAT_TOTAL_RUNS}"
else
  docker exec -t -u www-data "${WEBSERVER}" \
    php admin/tool/phpunit/cli/init.php \
      --force
fi
echo "============================================================================"
echo ">>> stopsection <<<"

# Run the test.
if [ "$TESTTORUN" == "behat" ]
then

  echo
  echo ">>> startsection Starting behat test run at $(date) <<<"
  echo "============================================================================"

  BEHAT_FORMAT_DOTS="--format=moodle_progress --out=std"
  if [ "$BEHAT_TOTAL_RUNS" -le 1 ]
  then
    BEHAT_FORMAT_PRETTY="--format=pretty --out=/shared/pretty.txt"
    BEHAT_FORMAT_JUNIT="--format=junit --out=/shared/log.junit"
    BEHAT_RUN_PROFILE="--profile=${BROWSER}"
  else
    BEHAT_FORMAT_PRETTY="--format=pretty --out=/shared/pretty{runprocess}.txt --replace={runprocess}"
    BEHAT_FORMAT_JUNIT="--format=junit --out=/shared/log{runprocess}.junit --replace={runprocess}"
    BEHAT_RUN_PROFILE="--profile=${BROWSER}{runprocess}"
  fi

  if [ -n "${TAGS}" ]
  then
    TAGS="--tags=${TAGS}"
  fi

  if [ -n "${NAME}" ]
  then
    NAME="--name=${NAME}"
  fi

  CMD=(php admin/tool/behat/cli/run.php
    ${BEHAT_FORMAT_DOTS}
    ${BEHAT_FORMAT_PRETTY}
    ${BEHAT_FORMAT_JUNIT}
    ${BEHAT_RUN_SUITE}
    ${BEHAT_RUN_PROFILE}
    ${TAGS}
    "${NAME}")

  ITER=0
  EXITCODE=0
  while [[ ${ITER} -lt ${RUNCOUNT} ]]
  do
    echo ${CMD[@]}
    docker exec -t -u www-data "${WEBSERVER}" "${CMD[@]}"
    EXITCODE=$(($EXITCODE + $?))
    ITER=$(($ITER+1))
  done
  echo "============================================================================"
  echo ">>> stopsection <<<"

  # Re-run failed scenarios, to ensure they are true fails.
  # If we are running a single, we don't need to check for each run.
  if [ ${EXITCODE} -eq 0 ]
  then
    echo "============================================================================"
    echo "== Exit code: ${EXITCODE}"
    echo "== Test result: Pass"
    echo "== End time $(date)"
    echo "============================================================================"
  else
    echo "============================================================================"
    echo "== Exit code: ${EXITCODE}"
    echo "== Test result: Unstable"
    echo "== End time $(date)"
    echo "============================================================================"

    # Perform reruns only if > 0
    if [ "$BEHAT_TOTAL_RUNS" -gt 0 ]
    then
      # Rerun behat, always 1 by 1 (no matter if the main run was single or parallel)
      if [ "$BEHAT_TOTAL_RUNS" -le 1 ]
      then
        # Was single
        for RERUN in `seq 1 "${BEHAT_NUM_RERUNS}"`
        do
          NEWEXITCODE=0
          CONFIGPATH="/var/www/behatdata/run/behatrun/behat/behat.yml"
          if [ "$MOODLE_VERSION" -lt "32" ]
          then
            CONFIGPATH="/var/www/behatdata/run/behat/behat.yml"
          fi

          echo ">>> startsection Running behat again (rerun #${RERUN}) for failed steps <<<"
          echo "============================================================================"
          CMD=(vendor/bin/behat
            --config ${CONFIGPATH}
            --profile=${BROWSER}
            ${BEHAT_FORMAT_DOTS}
            --format=pretty --out=/shared/pretty_rerun${RERUN}.txt
            --format=junit --out=/shared/log_rerun${RERUN}.junit
            ${BEHAT_RUN_SUITE}
            ${TAGS}
            "${NAME}"
            --no-colors
            --verbose
            --rerun)

          echo ${CMD[@]}
          docker exec -u www-data "${WEBSERVER}" "${CMD[@]}"
          NEWEXITCODE=$?
          if [ "$NEWEXITCODE" -eq 0 ]
          then
            break;
          fi
          echo "============================================================================"
          echo ">>> stopsection <<<"
        done
      else
        # Was parallel
        for RERUN in `seq 1 "${BEHAT_NUM_RERUNS}"`
        do
          NEWEXITCODE=0
          for RUN in `seq 1 "${BEHAT_TOTAL_RUNS}"`
          do
            # Check is the previous build failed
            status=$((1 << $RUN-1))
            if [ $(($status & $EXITCODE)) -eq 0 ]
            then
              continue
            fi

            CONFIGPATH="/var/www/behatdata/run/behatrun${RUN}/behat/behat.yml"
            if [ "$MOODLE_VERSION" -lt "32" ]
            then
              CONFIGPATH="/var/www/behatdata/run${RUN}/behat/behat.yml"
            fi

            echo ">>> startsection Running behat again (rerun #${RERUN}) for failed steps on process ${RUN} <<<"
            echo "============================================================================"

            docker exec -t -w /var/www/html "${WEBSERVER}" bash -c \
              "if [ ! -L \"behatrun${RUN}\" ]; then ln -s . \"behatrun${RUN}\"; fi"

            CMD=(vendor/bin/behat
              --config ${CONFIGPATH}
              --profile=${BROWSER}${RUN}
              ${BEHAT_FORMAT_DOTS}
              --format=pretty --out=/shared/pretty${RUN}_rerun${RERUN}.txt
              --format=junit --out=/shared/log${RUN}_rerun${RERUN}.junit
              ${BEHAT_RUN_SUITE}
              ${TAGS}
              "${NAME}"
              --no-colors
              --verbose
              --rerun)

            echo ${CMD[@]}
            docker exec -u www-data "${WEBSERVER}" "${CMD[@]}"
            if [ $? -ne 0 ]
            then
              NEWEXITCODE=$(($NEWEXITCODE + $status))
            fi
            echo "============================================================================"
            echo ">>> stopsection <<<"
          done
          EXITCODE=$NEWEXITCODE
          if [ "$NEWEXITCODE" -eq 0 ]
          then
            break;
          fi
        done
      fi
    fi
  fi

  # Update the timing file
  if [ ! -z "$BEHAT_TIMING_FILENAME" ]
  then
    cp "${OUTPUTDIR}"/timing.json "${TIMINGSOURCE}"
  fi
else

  echo
  echo ">>> startsection Starting phpunit run at $(date) <<<"
  echo "============================================================================"

  if [ -n "${TAGS}" ]
  then
    PHPUNIT_FILTER="--filter ${TAGS}"
  else
    PHPUNIT_FILTER=""
  fi

  if [ -n "${TESTSUITE}" ]
  then
    PHPUNIT_SUITE="--testsuite ${TESTSUITE}"
  else
    PHPUNIT_SUITE=""
  fi

  CMD="php vendor/bin/phpunit"
  CMD="${CMD} --disallow-test-output"
  if [ "$MOODLE_VERSION" -gt "31" ]
  then
    # Only for phpunit 5 and above (aka post 31_STABLE)
    # TODO: Remove condition once 31_STABLE is out.
    CMD="${CMD} --fail-on-risky"
  fi
  CMD="${CMD} --log-junit /shared/log.junit"
  CMD="${CMD} ${PHPUNIT_FILTER}"
  CMD="${CMD} ${PHPUNIT_SUITE}"
  CMD="${CMD} --verbose"

  ITER=0
  EXITCODE=0
  while [[ ${ITER} -lt ${RUNCOUNT} ]]
  do
    docker exec -t "${WEBSERVER}" ${CMD}
    EXITCODE=$(($EXITCODE + $?))
    ITER=$(($ITER+1))
  done

  echo "============================================================================"
  echo ">>> stopsection <<<"

fi

echo
echo ">>> startsection Cleaning workspace<<<"
echo "============================================================================"

# Store the docker container logs.
docker ps -a --filter name=${UUID}
for container in `docker ps -a --format "{{.ID}}~{{.Names}}" --filter name=${UUID}`
do
    image=$(echo $container | cut -d'~' -f1)
    name=$(echo $container | cut -d'~' -f2)
    name=${name%"${UUID}"} # Get rid of the UUID for naming log files.
    echo "Exporting ${name} logs to ${OUTPUTDIR}/${name}.gz"
    docker logs "${image}" 2>&1 | gzip > "${OUTPUTDIR}"/${name}.gz
done

docker exec -t "${WEBSERVER}" \
  chown -R "${UID}:${GROUPS[0]}" /shared

echo "============================================================================"
echo ">>> stopsection <<<"

echo
echo "============================================================================"
echo "== Exit summary":
echo "== Exit code: ${EXITCODE}"
echo "============================================================================"

exit $EXITCODE
