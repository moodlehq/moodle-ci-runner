#!/bin/bash
set -u
set -o pipefail

CACHEDIR="/var/lib/jenkins/caches"
export COMPOSERCACHE="${COMPOSERCACHE:-${CACHEDIR}/composer}"
export CODEDIR="${CODEDIR:-${WORKSPACE}/moodle}"
export OUTPUTDIR="${WORKSPACE}"/"${BUILD_ID}"
export ENVIROPATH="${OUTPUTDIR}"/environment.list

# Which PHP Image to use.
export PHP_VERSION="7.1"
export PHP_SERVER_DOCKER="${PHP_SERVER_DOCKER:-moodlehq/moodle-php-apache:${PHP_VERSION}}"

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
    dbtouse=pgsql
  else
    dbtouse=${DBTORUN[ $(( ${dayoftheweek} - 1 )) ]}
  fi
  echo "Running against ${dbtouse}"
fi

if [ -z "$DBNAME" ]
then
  echo "No database name specified"
  exit 1
fi

if [ "${DBTYPE}" == "oci" ]
then
  export DBHOST="oracle:1521/xe"
  export DBUSER="system"
  export DBPASS="oracle"
  export DBPREFIX="${DBNAME}"
  export DBNAME="xe"
elif [ "${DBTYPE}" == "mssql" ]
then
  export DBHOST="sqlsrv"
  export DBUSER="sa"
  export DBPASS="Passw0rd!"
fi

export DBTYPE="${DBTYPE:-pgsql}"
export DBUSER="${DBUSER:-moodle}"
export DBPASS="${DBPASS:-moodle}"
export DBHOST="${DBHOST:-${DBTYPE}}"
export DBPORT="${DBPORT:-}"
export DBNAME="${DBNAME:-}"
export DBPREFIX="${DBPREFIX:-}"


# Setup Environment
UUID=$(uuid | sha1sum | awk '{print $1}')
UUID=${UUID:0:16}
echo "DBTYPE" >> "${ENVIROPATH}"
echo "DBHOST" >> "${ENVIROPATH}"
echo "DBPORT" >> "${ENVIROPATH}"
echo "DBUSER" >> "${ENVIROPATH}"
echo "DBPASS" >> "${ENVIROPATH}"
echo "DBNAME" >> "${ENVIROPATH}"
echo "PREFIX" >> "${ENVIROPATH}"
echo "BROWSER" >> "${ENVIROPATH}"
echo "WEBSERVER" >> "${ENVIROPATH}"

echo "============================================================================"
echo "== Job summary:"
echo "== Workspace: ${WORKSPACE}"
echo "== Build Id: ${BUILD_ID}"
echo "== Output directory: ${OUTPUTDIR}"
echo "== UUID: ${UUID}"
echo "== Container prefix: ${UUID}"
echo "== DBTYPE: ${DBTYPE}"
echo "== DBHOST: ${DBHOST}"
echo "== DBPORT: ${DBPORT}"
echo "== DBUSER: ${DBUSER}"
echo "== DBPASS: ${DBPASS}"
echo "== DBNAME: ${DBNAME}"
echo "== PREFIX: ${DBPREFIX}"
echo "== Environment: ${ENVIROPATH}"
echo "============================================================================"

# Setup the image cleanup.
function finish {
  echo "Stopping all docker images for ${UUID}"
  for image in `docker ps -a -q --filter name=${UUID}`
  do
      docker stop $image
  done
}
trap finish EXIT

function ctrl_c() {
  echo "============================================================================"
  echo "Job was cancelled at user request"
  echo "============================================================================"
  exit 255
}
trap ctrl_c INT


if [ "$TESTTORUN" == "behat" ]
then
  SELNAME=sel"${UUID}"
  if [ "$BROWSER" == "chrome" ]
  then
    SHMMAP="-v /dev/shm:/dev/shm"

    docker run \
      --network nightly \
      --name ${SELNAME} \
      --detach \
      $SHMMAP \
      -v "${CODEDIR}":/var/www/html \
      -p 5900:5900 \
      selenium/standalone-chrome
  else
    SHMMAP=''
    docker run \
      --network nightly \
      --name ${SELNAME} \
      --detach \
      $SHMMAP \
      -v "${CODEDIR}":/var/www/html \
      selenium/standalone-firefox:2.53.1
  fi

  export SELENIUMURL="http://${SELNAME}:4444"
  echo SELENIUMURL >> "${ENVIROPATH}"
fi

# Start the test server.
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
docker cp "${CODEDIR}"/. "${WEBSERVER}":/var/www/html

# Copy the config.php in place
docker cp /store/scripts/configs/config.template.php "${WEBSERVER}":/var/www/html/config.php

# Setup the DB.
if [ "$TESTTORUN" == "behat" ]
then
  # Setup Composer
  docker exec -t "${WEBSERVER}" \
    php admin/tool/behat/cli/init.php

  docker exec -t "${WEBSERVER}" \
    php admin/tool/behat/cli/util.php --drop

  docker exec -t "${WEBSERVER}" \
    php admin/tool/behat/cli/util.php --drop -j=10

  # Init tables.
  docker exec -t "${WEBSERVER}" \
    php admin/tool/behat/cli/init.php \
      -j="${BEHAT_TOTAL_RUNS}"
else
  docker exec -t "${WEBSERVER}" \
    php admin/tool/phpunit/cli/init.php \
      --force
fi

# Run the test.
if [ "$TESTTORUN" == "behat" ]
then
  BEHAT_FORMAT_DOTS="--format=moodle_progress --out=std"
  BEHAT_FORMAT_PRETTY="--format=pretty --out=/shared/pretty{runprocess}.txt --replace={runprocess}"
  BEHAT_FORMAT_JUNIT="--format=junit --out=/shared/log{runprocess}.junit --replace={runprocess}"
  MOODLE_VERSION=$(grep "\$branch" "${CODEDIR}"/version.php | sed "s/';.*//" | sed "s/^\$.*'//")

  if [ -n "$BEHAT_SUITE" ]
  then
    BEHAT_INIT_SUITE="-a=${BEHAT_SUITE}"
    BEHAT_RUN_SUITE="--suite=${BEHAT_SUITE}"
  else
    BEHAT_INIT_SUITE=""
    BEHAT_RUN_SUITE=""
  fi

  docker exec -t "${WEBSERVER}" \
    php admin/tool/behat/cli/run.php \
      ${BEHAT_INIT_SUITE} \
      ${BEHAT_FORMAT_DOTS} \
      ${BEHAT_FORMAT_PRETTY} \
      ${BEHAT_FORMAT_JUNIT} \
      ${BEHAT_RUN_SUITE}
  EXITCODE=$?

  # Re-run failed scenarios, to ensure they are true fails.
  # If we are running a single, we don't need to check for each run.
  if [ ${EXITCODE} -eq 0 ]
  then
    echo "============================================================================"
    echo "== Exit code: ${EXITCODE}"
    echo "== Test result: Pass"
    echo "============================================================================"
  else
    if [ "$BEHAT_TOTAL_RUNS" -le 1 ]
    then

      echo "============================================================================"
      echo "== Exit code: ${EXITCODE}"
      echo "== Test result: Rerunning"
      echo "============================================================================"

      CONFIGPATH="/var/www/behatdata/behatrun/behat/behat.yml"
      if [ "$MOODLE_VERSION" -lt "32" ]
      then
        CONFIGPATH="/var/www/behatdata/behat/behat.yml"
      fi

      echo "---Running behat again for failed steps---"
      CMD="vendor/bin/behat"
      CMD="${CMD} --config ${CONFIGPATH}"
      CMD="${CMD} ${BEHAT_FORMAT_DOTS}"
      CMD="${CMD} --format=pretty --out=/shared/pretty_rerun.txt"
      CMD="${CMD} --format=junit --out=/shared/log_rerun.junit"
      CMD="${CMD} ${BEHAT_RUN_SUITE}"
      CMD="${CMD} --verbose"
      CMD="${CMD} --rerun"

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

        echo "---Running behat again for failed steps on process ${RUN}  ---"

        docker exec -t "${WEBSERVER}" [ ! -L "behatrun{$RUN}" ] && docker exec -t "${WEBSERVER}" ln -s /var/www/html "behatrun${RUN}"
        CMD="vendor/bin/behat"
        CMD="${CMD} --config ${CONFIGPATH}"
        CMD="${CMD} ${BEHAT_FORMAT_DOTS}"
        CMD="${CMD} --format=pretty --out=/shared/pretty${RUN}_rerun.txt"
        CMD="${CMD} --format=junit --out=/shared/log${RUN}_rerun.junit"
        CMD="${CMD} ${BEHAT_RUN_SUITE}"
        CMD="${CMD} --verbose"
        CMD="${CMD} --rerun"

        docker exec -t "${WEBSERVER}" ${CMD}
        NEWEXITCODE=$(($NEWEXITCODE + $?))
      done
    fi
    EXITCODE=${NEWEXITCODE}
  fi

else
  docker exec -t "${WEBSERVER}" \
    php vendor/bin/phpunit \
      --log-junit "/shared/log.junit" \
      --verbose
  EXITCODE=$?

fi

echo "============================================================================"
echo "== Exit summary":
echo "== Exit code: ${EXITCODE}"
echo "============================================================================"

exit $EXITCODE
