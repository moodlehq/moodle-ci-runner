#!/usr/bin/env bash
#
# This file is part of the Moodle Continuous Integration Project.
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
# along with Moodle.  If not, see <https://www.gnu.org/licenses/>.

set -u
set -e
set -o pipefail

# Let's define some variables that will be used by the scripts.

# Base directory where the scripts are located.
BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Include the functions.
source "${BASEDIR}/lib.sh"

# Trap to finish the execution (exit and Ctrl+C).
trap trap_exit EXIT
trap trap_ctrl_c INT

# Verify that all the needed utilities are installed and available.
verify_utilities awk grep head mktemp pwd sed sha1sum sort tac tr true uniq uuid xargs

# Base directory to be used as workspace for the execution.
if [[ -z ${WORKSPACE:-} ]]; then
    # If not defined, create one.
    MKTEMP=$(mktemp -d)
    WORKSPACE="${MKTEMP}/workspace"
fi

# Base directory where the code is located.
CODEDIR="${CODEDIR:-${WORKSPACE}/moodle}"

# BUILD_ID, if not defined use the current PID.
BUILD_ID="${BUILD_ID:-$$}"

# Base directory to be shared with some containers that will read/write information there (timing, environment, logs... etc.).
SHAREDDIR="${WORKSPACE}"/"${BUILD_ID}"

# Ensure that the output directory exists.
# It must also be set with the sticky bit, and world writable.
mkdir -p "${SHAREDDIR}"
chmod -R g+sw,a+sw "${SHAREDDIR}"

# UUID to be used as suffix for the containers and other stuff.
UUID=$(uuid | sha1sum | awk '{print $1}' | head -c 16)

# Job type to run (from "jobtypes" directory).
JOBTYPE="${JOBTYPE:-phpunit}"

# Ensure that the job type is valid.
if [[ ! -f ${BASEDIR}"/jobtypes/"${JOBTYPE}/phpunit.sh ]]; then
  exit_error "ERROR: Invalid jobtype: ${JOBTYPE}"
fi

# Caches directories, used for composer, to accelerate git operations...
CACHEDIR="${CACHEDIR:-${HOME}/caches}"
COMPOSERCACHE="${COMPOSERCACHE:-${CACHEDIR}/composer}"

# BC compatibility with old replica names.
# TODO: Remove this once all the uses in CI are updated to use the new ones.
DBREPLICAS="${DBREPLICAS:-${DBSLAVES:-}}"
if [[ -n ${DBSLAVES:-} ]]; then
    print_warning "DBSLAVES variable is deprecated, use DBREPLICAS instead."
fi

# BC compatibility with old phpunit and behat variable names.
# TODO: Remove this once all the uses in CI are updated to use the new ones.
# PHPUnit:
PHPUNIT_TESTSUITE="${PHPUNIT_TESTSUITE:-${TESTSUITE:-}}"
PHPUNIT_FILTER="${PHPUNIT_FILTER:-${TAGS:-}}"
# Behat:
BEHAT_TAGS="${BEHAT_TAGS:-${TAGS:-}}"
BEHAT_NAME="${BEHAT_NAME:-${NAME:-}}"
# Print a warning if the old variables are used.
if [[ -n ${TESTSUITE:-} ]]; then
    print_warning "TESTSUITE variable is deprecated, use PHPUNIT_TESTSUITE instead."
fi
if [[ -n ${TAGS:-} ]]; then
    print_warning "TAGS variable is deprecated, use PHPUNIT_FILTER or BEHAT_TAGS instead."
fi
if [[ -n ${NAME:-} ]]; then
    print_warning "NAME variable is deprecated, use BEHAT_NAME instead."
fi

# Everything is ready, let's run the job.
run "${JOBTYPE}"

# All done, exit with the exit code of the job.
exit "${EXITCODE}"


# If the MOBILE_VERSION is not defined, the moodlemobile docker won't be executed.
export MOBILE_VERSION="${MOBILE_VERSION:-}"
export MOBILE_APP_PORT="${MOBILE_APP_PORT:-8100}"



# Test defaults
export BROWSER="${BROWSER:-chrome}"
export BROWSER_DEBUG="${BROWSER_DEBUG:-}"
export BROWSER_HEADLESS="${BROWSER_HEADLESS:-}"
export DISABLE_MARIONETTE=
export BEHAT_SUITE="${BEHAT_SUITE:-}"
export BEHAT_TAGS="${BEHAT_TAGS:-}"
export BEHAT_NAME="${BEHAT_NAME:-}"
export BEHAT_TOTAL_RUNS="${BEHAT_TOTAL_RUNS:-3}"
export BEHAT_NUM_RERUNS="${BEHAT_NUM_RERUNS:-1}"
export BEHAT_TIMING_FILENAME="${BEHAT_TIMING_FILENAME:-}"
export BEHAT_INCREASE_TIMEOUT="${BEHAT_INCREASE_TIMEOUT:-}"


# Remove some stuff that, simply, cannot be there based on $JOBTYPE
if [ "${JOBTYPE}" == "behat" ]
then
    PHPUNIT_TESTSUITE=
    PHPUNIT_FILTER=

    # If the --name option is going to be used, then disable any parallel execution, it's not worth
    # instantiating N sites for just running one feature/scenario.
    if [[ -n "${BEHAT_NAME}" ]] && [[ "${BEHAT_TOTAL_RUNS}" -gt 1 ]]; then
        echo "Note: parallel option disabled because of BEHAT_NAME (--name) behat option being used."
        BEHAT_TOTAL_RUNS=1
    fi

    # If the composer.json contains instaclick then we must disable marionette and use an older version of firefox.
    hasinstaclick=$((`c1grep instaclick "${CODEDIR}"/composer.json | wc -l`))
    if [[ ${hasinstaclick} -ge 1 ]]
    then
        export DISABLE_MARIONETTE=1
    fi
fi



if [ ! -z "$BEHAT_TIMING_FILENAME" ]
then
  mkdir -p "${WORKSPACE}/timing"
  TIMINGSOURCE="${WORKSPACE}/timing/${BEHAT_TIMING_FILENAME}"

  if [ -f "${TIMINGSOURCE}" ]
  then
    cp "${TIMINGSOURCE}" "${SHAREDDIR}"/timing.json
  else
    touch "${SHAREDDIR}"/timing.json
  fi
fi


echo "============================================================================"
echo "= Job summary <<<"
echo "============================================================================"
echo "== PHP version: ${PHP_VERSION}"
echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
echo "== DBTYPE: ${DBTYPE}"
echo "== DBTAG: ${DBTAG}"
echo "== DBREPLICAS: ${DBREPLICAS}"
echo "== BROWSER: ${BROWSER}"
echo "== BROWSER_DEBUG: ${BROWSER_DEBUG}"
echo "== BROWSER_HEADLESS: ${BROWSER_HEADLESS}"
echo "== DISABLE_MARIONETTE: ${DISABLE_MARIONETTE}"
echo "== MLBACKEND_PYTHON_VERSION: ${MLBACKEND_PYTHON_VERSION}"
echo "== RUNCOUNT: ${RUNCOUNT}"
echo "== BEHAT_TOTAL_RUNS: ${BEHAT_TOTAL_RUNS}"
echo "== BEHAT_NUM_RERUNS: ${BEHAT_NUM_RERUNS}"
echo "== BEHAT_INCREASE_TIMEOUT: ${BEHAT_INCREASE_TIMEOUT}"
echo "== BEHAT_SUITE: ${BEHAT_SUITE}"
echo "== TAGS: ${TAGS}"
echo "== BEHAT_NAME: ${BEHAT_NAME}"
echo "== MOBILE_APP_PORT: ${MOBILE_APP_PORT}"
echo "== MOBILE_VERSION: ${MOBILE_VERSION}"
echo "== PLUGINSTOINSTALL: ${PLUGINSTOINSTALL}"
echo "============================================================================"


if [ "$JOBTYPE" == "behat" ]
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
  SELCHROMEIMAGE="moodlehq/selenium-standalone-chrome:96.0-moodlehq"

  # Newer versions of Firefox do not allow Marionette to be disabled.
  # Version 47.0.1 is the latest version of Firefox we can support when Marionette is disabled.
  if [[ ${DISABLE_MARIONETTE} -ge 1 ]]
  then
      SELFIREFOXIMAGE="moodlehq/moodle-standalone-firefox:3.141.59_47.0.1"
  fi


  if [ "$BROWSER" == "chrome" ]
  then

    if [ ! -z "$MOBILE_VERSION" ]
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
  elif [ "$BROWSER" == "goutte" ] || [ "$BROWSER" == "browserkit" ]
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














# INIT
if [ "$JOBTYPE" == "behat" ]
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
fi
echo "============================================================================"




# Run the test.
if [ "$JOBTYPE" == "behat" ]
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

  if [ -n "${BEHAT_NAME}" ]
  then
    NAME="--name=${BEHAT_NAME}"
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
        for RERUN in $(seq 1 "${BEHAT_NUM_RERUNS}")
        do
          NEWEXITCODE=0
          CONFIGPATH="/var/www/behatdata/run/behatrun/behat/behat.yml"
          if [ "$MOODLE_BRANCH" -lt "32" ]
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
          EXITCODE=$NEWEXITCODE
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
            if [ "$MOODLE_BRANCH" -lt "32" ]
            then
              CONFIGPATH="/var/www/behatdata/run${RUN}/behat/behat.yml"
            fi

            echo ">>> startsection Running behat again (rerun #${RERUN}) for failed steps on process ${RUN} <<<"
            echo "============================================================================"

            docker exec -t -w /var/www/html -u www-data "${WEBSERVER}" bash -c \
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
    cp "${SHAREDDIR}"/timing.json "${TIMINGSOURCE}"
  fi

fi




