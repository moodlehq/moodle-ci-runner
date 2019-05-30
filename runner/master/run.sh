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

pushd `dirname $0` > /dev/null
SCRIPTPATH=`pwd`
popd > /dev/null

CACHEDIR="${CACHEDIR:-${HOME}/caches}"
export COMPOSERCACHE="${COMPOSERCACHE:-${CACHEDIR}/composer}"
export CODEDIR="${CODEDIR:-${WORKSPACE}/moodle}"
export OUTPUTDIR="${WORKSPACE}"/"${BUILD_ID}"
export ENVIROPATH="${OUTPUTDIR}"/environment.list

# Which PHP Image to use.
export PHP_VERSION="${PHP_VERSION:-7.1}"
export PHP_SERVER_DOCKER="${PHP_SERVER_DOCKER:-moodlehq/moodle-php-apache:${PHP_VERSION}}"

# Which Moodle version (XY) is being used.
export MOODLE_VERSION=$(grep "\$branch" "${CODEDIR}"/version.php | sed "s/';.*//" | sed "s/^\$.*'//")

# Default type of test to run.
# phpunit or behat.
export TESTTORUN="${TESTTORUN:-phpunit}"

# Default DB settings.
# Todo: Tidy this up properly.
export DBTYPE="${DBTYPE:-pgsql}"
export DBTORUN="${DBTORUN:-}"

# Test defaults
export BROWSER="${BROWSER:-chrome}"
export BEHAT_SUITE="${BEHAT_SUITE:-}"
export BEHAT_TOTAL_RUNS="${BEHAT_TOTAL_RUNS:-3}"
export TAGS="${TAGS:-}"
export NAME="${NAME:-}"
export TESTSUITE="${TESTSUITE:-}"
export RUNCOUNT="${RUNCOUNT:-1}"
export BEHAT_TIMING_FILENAME="${BEHAT_TIMING_FILENAME:-}"
export BEHAT_INCREASE_TIMEOUT="${BEHAT_INCREASE_TIMEOUT:-}"

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
export DBHOST=db"${UUID}"
export DBTYPE="${DBTYPE:-pgsql}"
export DBUSER="${DBUSER:-moodle}"
export DBPASS="${DBPASS:-moodle}"
export DBHOST="${DBHOST:-${DBTYPE}}"
export DBNAME="moodle"

echo "DBTYPE" >> "${ENVIROPATH}"
echo "DBHOST" >> "${ENVIROPATH}"
echo "DBUSER" >> "${ENVIROPATH}"
echo "DBPASS" >> "${ENVIROPATH}"
echo "DBNAME" >> "${ENVIROPATH}"
echo "DBCOLLATION" >> "${ENVIROPATH}"
echo "BROWSER" >> "${ENVIROPATH}"
echo "WEBSERVER" >> "${ENVIROPATH}"
echo "BEHAT_TOTAL_RUNS" >> "${ENVIROPATH}"
echo "BEHAT_TIMING_FILENAME" >> "${ENVIROPATH}"
echo "BEHAT_INCREASE_TIMEOUT" >> "${ENVIROPATH}"

echo ">>> startsection Job summary <<<"
echo "============================================================================"
echo "== Workspace: ${WORKSPACE}"
echo "== Build Id: ${BUILD_ID}"
echo "== Output directory: ${OUTPUTDIR}"
echo "== UUID: ${UUID}"
echo "== Container prefix: ${UUID}"
echo "== PHP Version: ${PHP_VERSION}"
echo "== DBTORUN: ${DBTORUN}"
echo "== DBTYPE: ${DBTYPE}"
echo "== TESTTORUN: ${TESTTORUN}"
echo "== BROWSER: ${BROWSER}"
echo "== BEHAT_TOTAL_RUNS: ${BEHAT_TOTAL_RUNS}"
echo "== BEHAT_SUITE: ${BEHAT_SUITE}"
echo "== TAGS: ${TAGS}"
echo "== NAME: ${NAME}"
echo "== TESTSUITE: ${TESTSUITE}"
echo "== Environment: ${ENVIROPATH}"
echo "============================================================================"
echo ">>> stopsection <<<"

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
  docker run \
    --detach \
    --name ${DBHOST} \
    --network "${NETWORK}" \
    -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
    -e MYSQL_DATABASE="${DBNAME}" \
    -e MYSQL_USER="${DBUSER}" \
    -e MYSQL_PASSWORD="${DBPASS}" \
    --tmpfs /var/lib/mysql:rw \
    -v $SCRIPTPATH/mysql.d:/etc/mysql/conf.d \
    mysql:5\
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_bin \
    --innodb_file_format=barracuda \
    --innodb_file_per_table=On \
    --innodb_large_prefix=On

  export DBCOLLATION=utf8mb4_bin

  # Wait few sec, before executing commands.
  sleep 20

elif [ "${DBTYPE}" == "mariadb" ]
then
  docker run \
    --detach \
    --name ${DBHOST} \
    --network "${NETWORK}" \
    -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
    -e MYSQL_DATABASE="${DBNAME}" \
    -e MYSQL_USER="${DBUSER}" \
    -e MYSQL_PASSWORD="${DBPASS}" \
    --tmpfs /var/lib/mysql:rw \
    -v $SCRIPTPATH/mysql.d:/etc/mysql/conf.d \
    mariadb:10.1 \
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_bin \
    --innodb_file_format=barracuda \
    --innodb_file_per_table=On \
    --innodb_large_prefix=On

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
    moodlehq/moodle-db-oci

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
    microsoft/mssql-server-linux:2017-GA

  sleep 10

  docker exec ${DBHOST} /opt/mssql-tools/bin/sqlcmd -S localhost -U "${DBUSER}" -P "${DBPASS}" -Q "CREATE DATABASE ${DBNAME} COLLATE LATIN1_GENERAL_CS_AS"
  docker exec ${DBHOST} /opt/mssql-tools/bin/sqlcmd -S localhost -U "${DBUSER}" -P "${DBPASS}" -Q "ALTER DATABASE ${DBNAME} SET ANSI_NULLS ON"
  docker exec ${DBHOST} /opt/mssql-tools/bin/sqlcmd -S localhost -U "${DBUSER}" -P "${DBPASS}" -Q "ALTER DATABASE ${DBNAME} SET QUOTED_IDENTIFIER ON"
  docker exec ${DBHOST} /opt/mssql-tools/bin/sqlcmd -S localhost -U "${DBUSER}" -P "${DBPASS}" -Q "ALTER DATABASE ${DBNAME} SET READ_COMMITTED_SNAPSHOT ON"

elif [ "${DBTYPE}" == "pgsql" ]
then

  docker run \
    --detach \
    --name ${DBHOST} \
    --network "${NETWORK}" \
    -e POSTGRES_USER=moodle \
    -e POSTGRES_PASSWORD=moodle \
    -e POSTGRES_DB=initial \
    -v $SCRIPTPATH/pgsql.d:/docker-entrypoint-initdb.d \
    --tmpfs /var/lib/postgresql/data:rw \
    postgres:9.6.7

  # Wait few sec, before executing commands.
  sleep 10

  # Create dbs.
  docker exec ${DBHOST} psql -U postgres -c "CREATE DATABASE ${DBNAME} WITH OWNER moodle ENCODING 'UTF8' LC_COLLATE='en_US.utf8' LC_CTYPE='en_US.utf8' TEMPLATE=template0;"

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
echo "== DBUSER: ${DBUSER}"
echo "== DBPASS: ${DBPASS}"
echo "== DBNAME: ${DBNAME}"

docker logs "${DBHOST}"
echo "============================================================================"
echo ">>> stopsection <<<"

if [ "${TESTTORUN}" == "phpunit" ]
then
  echo
  echo ">>> startsection Starting supplemental services <<<"
  echo "============================================================================"
  EXTTESTNAME=ext"${UUID}"

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


#  export SOLRTESTNAME=solr"${UUID}"
#  docker run \
#    --detach \
#    --name ${SOLRTESTNAME} \
#    --network "${NETWORK}" \
#    solr:7 \
#    solr-precreate test
#
#  echo SOLRTESTNAME >> "${ENVIROPATH}"
#  docker logs ${SOLRTESTNAME}


  export REDISTESTNAME=redis"${UUID}"
  docker run \
    --detach \
    --name ${REDISTESTNAME} \
    --network "${NETWORK}" \
    redis:3

  echo REDISTESTNAME >> "${ENVIROPATH}"
  docker logs ${REDISTESTNAME}


  echo "============================================================================"
  echo ">>> stopsection <<<"

elif [ "$TESTTORUN" == "behat" ]
then
  echo
  echo ">>> startsection Starting selenium server <<<"
  echo "============================================================================"

  SHMMAP="--shm-size=2g"

  HASSELENIUM=1

  if [ "$BROWSER" == "chrome" ]
  then
    IONICHOSTNAME="ionic${UUID}"
    echo $IONICHOSTNAME

    docker run \
      --network "${NETWORK}" \
      --name ${IONICHOSTNAME} \
      --detach \
      moodlehq/moodlemobile2:latest

    export "IONICURL"="http://${IONICHOSTNAME}:8100"
    echo "IONICURL" >> "${ENVIROPATH}"

    SELVERSION="3.141.59-mercury"
    ITER=0
    while [[ ${ITER} -lt ${BEHAT_TOTAL_RUNS} ]]
    do
      SELITERNAME=sel"${ITER}${UUID}"
      docker run \
        --network "${NETWORK}" \
        --name ${SELITERNAME} \
        --detach \
        $SHMMAP \
        -v "${CODEDIR}":/var/www/html \
        selenium/standalone-chrome:${SELVERSION}

      export "SELENIUMURL_${ITER}"="http://${SELITERNAME}:4444"
      echo "SELENIUMURL_${ITER}" >> "${ENVIROPATH}"

      ITER=$(($ITER+1))
    done
  elif [ "$BROWSER" == "firefox" ]
  then

    FFSELVERSION="3.141.59_47.0.1"
    ITER=0
    while [[ ${ITER} -lt ${BEHAT_TOTAL_RUNS} ]]
    do
      SELITERNAME=sel"${ITER}${UUID}"
      docker run \
        --network "${NETWORK}" \
        --name ${SELITERNAME} \
        --detach \
        $SHMMAP \
        -v "${CODEDIR}":/var/www/html \
        moodlehq/moodle-standalone-firefox:${FFSELVERSION}

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

      ITER=0
      while [[ ${ITER} -lt ${BEHAT_TOTAL_RUNS} ]]
      do
        docker logs sel"${ITER}${UUID}"
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
export WEBSERVER=run"${UUID}"
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
      -j="${BEHAT_TOTAL_RUNS}"

  docker exec -t "${WEBSERVER}" bash -c 'chown -R www-data:www-data /var/www/*'

  docker exec -t -u www-data "${WEBSERVER}" \
    php admin/tool/behat/cli/init.php \
      ${BEHAT_INIT_SUITE} \
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
  BEHAT_FORMAT_PRETTY="--format=pretty --out=/shared/pretty{runprocess}.txt --replace={runprocess}"
  BEHAT_FORMAT_JUNIT="--format=junit --out=/shared/log{runprocess}.junit --replace={runprocess}"

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

    # Rerun behat, always 1 by 1 (no matter if the main run was single or parallel)
    if [ "$BEHAT_TOTAL_RUNS" -le 1 ]
    then
      # Was single
      CONFIGPATH="/var/www/behatdata/run/behatrun/behat/behat.yml"
      if [ "$MOODLE_VERSION" -lt "32" ]
      then
        CONFIGPATH="/var/www/behatdata/run/behat/behat.yml"
      fi

      echo ">>> startsection Running behat again for failed steps <<<"
      echo "============================================================================"
      CMD=(vendor/bin/behat
        --config ${CONFIGPATH}
        ${BEHAT_FORMAT_DOTS}
        --format=pretty --out=/shared/pretty_rerun.txt
        --format=junit --out=/shared/log_rerun.junit
        ${BEHAT_RUN_SUITE}
        ${TAGS}
        "${NAME}"
        --no-color
        --verbose
        --rerun)

      echo ${CMD[@]}
      docker exec -t -u www-data "${WEBSERVER}" "${CMD[@]}"
      NEWEXITCODE=$?
      echo "============================================================================"
      echo ">>> stopsection <<<"
    else
      # Was parallel
      NEWEXITCODE=0
      for RUN in `seq 1 "${BEHAT_TOTAL_RUNS}"`
      do
        # Check is the previous build failed
        status=$((1 << $RUN-1))
        CURRENTRUNEXITCODE=$(($status & $EXITCODE))
        if [ $CURRENTRUNEXITCODE -eq 0 ]
        then
          continue
        fi

        CONFIGPATH="/var/www/behatdata/run/behatrun${RUN}/behat/behat.yml"
        if [ "$MOODLE_VERSION" -lt "32" ]
        then
          CONFIGPATH="/var/www/behatdata/run${RUN}/behat/behat.yml"
        fi

        echo ">>> startsection Running behat again for failed steps on process ${RUN} <<<"
        echo "============================================================================"

        docker exec -t "${WEBSERVER}" [ ! -L "behatrun{$RUN}" ] && docker exec -t "${WEBSERVER}" ln -s /var/www/html "behatrun${RUN}"
        CMD=(vendor/bin/behat
          --config ${CONFIGPATH}
          ${BEHAT_FORMAT_DOTS}
          --format=pretty --out=/shared/pretty${RUN}_rerun.txt
          --format=junit --out=/shared/log${RUN}_rerun.junit
          ${BEHAT_RUN_SUITE}
          ${TAGS}
          "${NAME}"
          --no-colors
          --verbose
          --rerun)

        echo ${CMD[@]}
        docker exec -t -u www-data "${WEBSERVER}" "${CMD[@]}"
        NEWEXITCODE=$(($NEWEXITCODE + $?))
        echo "============================================================================"
        echo ">>> stopsection <<<"
      done
    fi
    EXITCODE=${NEWEXITCODE}
  fi

  # Store the web server logs.
  docker logs "${WEBSERVER}" 2>&1 | gzip > "${OUTPUTDIR}"/webserver.gz

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
