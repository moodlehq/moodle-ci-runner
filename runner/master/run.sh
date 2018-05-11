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
export TESTSUITE="${TESTSUITE:-}"
export RUNCOUNT="${RUNCOUNT:-1}"

mkdir -p "${OUTPUTDIR}"
rm -f "${ENVIROPATH}"
touch "${ENVIROPATH}"

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
docker network list  --filter name=nightly | grep nightly > /dev/null
if [ $? -ne 0 ]
then
    docker network create nightly
fi
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
    --network nightly \
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
    --network nightly \
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
    --network nightly \
    -v $SCRIPTPATH/oracle.d/tmpfs.sh:/docker-entrypoint-initdb.d/tmpfs.sh \
    --tmpfs /var/lib/oracle \
    --shm-size=2g \
    -e ORACLE_DISABLE_ASYNCH_IO=true \
    moodlehq/moodle-db-oracle

  sleep 120

  export DBPASS="m@0dl3ing"
  export DBNAME="XE"

elif [ "${DBTYPE}" == "mssql" ] || [ "${DBTYPE}" == "sqlsrv" ]
then

  export DBUSER="sa"
  export DBPASS="Passw0rd!"

  docker run \
    --detach \
    --name ${DBHOST} \
    --network nightly \
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
    --network nightly \
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
    --network nightly \
    moodlehq/moodle-exttests:latest

  export EXTTESTURL="http://${EXTTESTNAME}"
  echo EXTTESTURL >> "${ENVIROPATH}"
  docker logs ${EXTTESTNAME}


  LDAPTESTNAME=ldap"${UUID}"

  docker run \
    --detach \
    --name ${LDAPTESTNAME} \
    --network nightly \
    larrycai/openldap

  export LDAPTESTURL="ldap://${LDAPTESTNAME}"
  echo LDAPTESTURL >> "${ENVIROPATH}"
  docker logs ${LDAPTESTNAME}


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

    SELVERSION="3.11.0-dysprosium"
    ITER=0
    while [[ ${ITER} -lt ${BEHAT_TOTAL_RUNS} ]]
    do
      SELITERNAME=sel"${ITER}${UUID}"
      docker run \
        --network nightly \
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

    ITER=0
    while [[ ${ITER} -lt ${BEHAT_TOTAL_RUNS} ]]
    do
      SELITERNAME=sel"${ITER}${UUID}"
      docker run \
        --network nightly \
        --name ${SELITERNAME} \
        --detach \
        $SHMMAP \
        -v "${CODEDIR}":/var/www/html \
        rajeshtaneja/selenium:2.53.1 firefox

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
  --network nightly \
  --name "${WEBSERVER}" \
  --detach \
  --env-file "${ENVIROPATH}" \
  -v "${COMPOSERCACHE}:/root/.composer:rw" \
  -v "${OUTPUTDIR}":/shared \
  ${PHP_SERVER_DOCKER}

# Copy code in place.
echo "== Copying code in place"
docker cp "${CODEDIR}"/. "${WEBSERVER}":/var/www/html

# Copy the config.php in place
echo "== Copying configuration"
docker cp "${SCRIPTPATH}/config.template.php" "${WEBSERVER}":/var/www/html/config.php

echo "============================================================================"
docker logs "${WEBSERVER}"
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

  docker exec -t "${WEBSERVER}" \
    php admin/tool/behat/cli/init.php \
      ${BEHAT_INIT_SUITE} \
      -j="${BEHAT_TOTAL_RUNS}"
  docker exec -it "${WEBSERVER}" chown -R www-data /var/www/moodledata
else
  docker exec -t "${WEBSERVER}" \
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

  CMD="php admin/tool/behat/cli/run.php"
  CMD="${CMD} ${BEHAT_FORMAT_DOTS}"
  CMD="${CMD} ${BEHAT_FORMAT_PRETTY}"
  CMD="${CMD} ${BEHAT_FORMAT_JUNIT}"
  CMD="${CMD} ${TAGS}"
  CMD="${CMD} ${BEHAT_RUN_SUITE}"

  ITER=0
  EXITCODE=0
  while [[ ${ITER} -lt ${RUNCOUNT} ]]
  do
    echo ${CMD}
    docker exec -t "${WEBSERVER}" ${CMD}
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

    if [ "$BEHAT_TOTAL_RUNS" -le 1 ]
    then
      # A single (non-parallel) behat run.

      CONFIGPATH="/var/www/behatdata/behatrun/behat/behat.yml"
      if [ "$MOODLE_VERSION" -lt "32" ]
      then
        CONFIGPATH="/var/www/behatdata/behat/behat.yml"
      fi

      echo ">>> startsection Running behat again for failed steps <<<"
      echo "============================================================================"
      CMD="vendor/bin/behat"
      CMD="${CMD} --config ${CONFIGPATH}"
      CMD="${CMD} ${BEHAT_FORMAT_DOTS}"
      CMD="${CMD} --format=pretty --out=/shared/pretty_rerun.txt"
      CMD="${CMD} --format=junit --out=/shared/log_rerun.junit"
      CMD="${CMD} ${BEHAT_RUN_SUITE}"
      CMD="${CMD} ${TAGS}"
      CMD="${CMD} --verbose"
      CMD="${CMD} --rerun"
      echo "============================================================================"
      echo ">>> stopsection <<<"

      docker exec -t "${WEBSERVER}" ${CMD}
      NEWEXITCODE=$?
    else
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

        CONFIGPATH="/var/www/behatdata/behatrun${RUN}/behat/behat.yml"
        if [ "$MOODLE_VERSION" -lt "32" ]
        then
          CONFIGPATH="/var/www/behatdata${RUN}/behat/behat.yml"
        fi

        echo ">>> startsection Running behat again for failed steps on process ${RUN} <<<"
        echo "============================================================================"

        docker exec -t "${WEBSERVER}" [ ! -L "behatrun{$RUN}" ] && docker exec -t "${WEBSERVER}" ln -s /var/www/html "behatrun${RUN}"
        CMD="vendor/bin/behat"
        CMD="${CMD} --config ${CONFIGPATH}"
        CMD="${CMD} ${BEHAT_FORMAT_DOTS}"
        CMD="${CMD} --format=pretty --out=/shared/pretty${RUN}_rerun.txt"
        CMD="${CMD} --format=junit --out=/shared/log${RUN}_rerun.junit"
        CMD="${CMD} ${BEHAT_RUN_SUITE}"
        CMD="${CMD} ${TAGS}"
        CMD="${CMD} --verbose"
        CMD="${CMD} --rerun"

        docker exec -t "${WEBSERVER}" ${CMD}
        NEWEXITCODE=$(($NEWEXITCODE + $?))
        echo "============================================================================"
        echo ">>> stopsection <<<"
      done
    fi
    EXITCODE=${NEWEXITCODE}
  fi

  # Store the web server logs.
  docker logs "${WEBSERVER}" 2>&1 | gzip > "${OUTPUTDIR}"/webserver.gz
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
