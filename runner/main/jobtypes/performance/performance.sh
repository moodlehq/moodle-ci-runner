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

# Performance job type functions.

# Performance needed variables to go to the env file.
function performance_to_env_file() {
    local env=(
        DBTYPE
        DBTAG
        DBHOST
        DBNAME
        DBUSER
        DBPASS
        DBCOLLATION
        DBREPLICAS
        DBHOST_DBREPLICA
        WEBSERVER
        MOODLE_WWWROOT
        SITESIZE
        TARGET_FILE
    )
    echo "${env[@]}"
}

# Performance information to be added to the summary.
function performance_to_summary() {
    echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
    echo "== PHP version: ${PHP_VERSION}"
    echo "== DBTYPE: ${DBTYPE}"
    echo "== DBTAG: ${DBTAG}"
    echo "== DBREPLICAS: ${DBREPLICAS}"
    echo "== MOODLE_CONFIG: ${MOODLE_CONFIG}"
    echo "== PLUGINSTOINSTALL: ${PLUGINSTOINSTALL}"
    echo "== SITESIZE: ${SITESIZE}"
    echo "== TARGET_FILE: ${TARGET_FILE}"
}

# This job type defines the following env variables
function performance_env() {
    env=(
        RUNCOUNT
        EXITCODE
    )
    echo "${env[@]}"
}

# Performance needed modules. Note that the order is important.
function performance_modules() {
    local modules=(
        env
        summary
        moodle-branch
        docker
        docker-logs
        git
        browser
        plugins
        docker-database
        docker-php
        moodle-config
        moodle-core-copy
        docker-healthy
        docker-summary
        docker-jmeter
    )
    echo "${modules[@]}"
}

# Performance job type checks.
function performance_check() {
    # Check all module dependencies.
    verify_modules $(performance_modules)

    # These env variables must be set for the job to work.
    verify_env UUID WORKSPACE SHAREDDIR ENVIROPATH WEBSERVER GOOD_COMMIT BAD_COMMIT
}

# Performance job type init.
function performance_config() {
    EXITCODE=0

    export MOODLE_WWWROOT="http://${WEBSERVER}"
    export SITESIZE="${SITESIZE:-XS}"
    export COURSENAME="performance_course"

    # Default target file (relative to WORKSPACE) where rundata.json will be stored.
    export TARGET_FILE="${TARGET_FILE:-storage/performance/${MOODLE_BRANCH}/rundata.json}"
}

# Performance job type setup.
function performance_setup() {
    # If both GOOD_COMMIT and BAD_COMMIT are not set, we are going to run a normal session.
    # (for bisect sessions we don't have to setup the environment).
    if [[ -z "${GOOD_COMMIT}" ]] && [[ -z "${BAD_COMMIT}" ]]; then
        performance_setup_normal
    fi
}

# Performance job type setup for normal mode.
function performance_setup_normal() {
    # Init the Performance site.
    echo
    echo ">>> startsection Initialising Performance environment at $(date)<<<"
    echo "============================================================================"
    local initcmd
    performance_initcmd initcmd # By nameref.
    echo "Running: ${initcmd[*]}"

    plugin_repo="https://github.com/moodlehq/moodle-local_performancetool"
    dest="/var/www/html/local/performancetool"

    echo "Installing moodle-local_performancetool plugin into ${dest}"

    # Ensure host shared directories exist and are writable so plugin can save files.
    mkdir -p "${SHAREDDIR}/planfiles" "${SHAREDDIR}/output/logs" "${SHAREDDIR}/output/runs"
    chmod -R 2777 "${SHAREDDIR}" || true

    # Clone the performance data generator plugin inside the container.
    docker exec "${WEBSERVER}" sh -c "git clone --depth 1 ${plugin_repo} ${dest}"

    docker exec -t -u www-data "${WEBSERVER}" "${initcmd[@]}"

    # Execute the script inside the container as www-data
    docker exec -t -u www-data "${WEBSERVER}" php "${dest}"
    exec_status=$?

    if [[ $exec_status -ne 0 ]]; then
      echo "Error: php returned exit ${exec_status} when executing ${dest}"
      exit $exec_status
    fi
    performance_perftoolcmd perftoolcmd
    docker exec -t -u www-data "${WEBSERVER}" "${perftoolcmd[@]}"

    # Copy generated plan files (jmx, csv) from container to host-shared dir.
    echo "Copying generated plan files from container to ${SHAREDDIR}/planfiles"

    docker exec -u root "${WEBSERVER}" bash -lc "\
      mkdir -p /shared/planfiles && \
      cp -a /var/www/html/local/performancetool/planfiles/. /shared/planfiles/ || true && \
      chown -R www-data:www-data /shared/planfiles || true"

    chmod -R 2777 "${SHAREDDIR}/planfiles" || true
    echo "Files in ${SHAREDDIR}/planfiles:"
    ls -la "${SHAREDDIR}/planfiles" || true

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Returns (by nameref) an array with the command needed to init the Performance site.
function performance_initcmd() {
    local -n cmd=$1
    # We need to determine the init suite to use.
    local initsuite=""


    # Build the complete init command.
    cmd=(
        php admin/cli/install_database.php \
            --agree-license \
            --fullname="Moodle Performance Test"\
            --shortname="moodle" \
            --adminuser=admin \
            --adminpass=adminpass
    )
}

# Returns (by nameref) an array with the command needed to init the Performance site.
function performance_perftoolcmd() {
    local -n cmd=$1
    # We need to determine the init suite to use.
    local initsuite=""

    # Build the complete init command.
    cmd=(
        php local/performancetool/generate_test_data.php \
            --size="${SITESIZE}" \
            --planfilespath="/shared" \
            --quiet="false"
    )
}

# Performance job type run.
function performance_run() {

    echo ">>> startsection Starting Performance main run at $(date) <<<"
    echo "============================================================================"

    datestring=`date '+%Y%m%d%H%M'`
    # Get the plan file name.
    testplanfile=`ls "${SHAREDDIR}"/*.jmx | head -1 | sed "s@${SHAREDDIR}@/shared@"`
    echo "Using test plan file: ${testplanfile}"
    testusersfile=`ls "${SHAREDDIR}"/*.csv | head -1 | sed "s@${SHAREDDIR}@/shared@"`
    echo "Using test users file: ${testusersfile}"
    group="${MOODLE_BRANCH}"
    description="${GIT_COMMIT}"
    siteversion=""
    sitebranch="${MOODLE_BRANCH}"
    sitecommit="${GIT_COMMIT}"
    runoutput="${SHAREDDIR}/output/logs/run.log"

    # Ensure run log directory exists and is writable so 'tee' can create the file.
    mkdir -p "$(dirname "${runoutput}")"
    chmod -R 2777 "${SHAREDDIR}/output/logs" || true

    # Calculate the command to run. The function will return the command in the passed array.
    local jmeterruncmd=
    performance_main_command jmeterruncmd # By nameref.

    echo "Running performance command: ${jmeterruncmd[*]}"
    echo ">>> Performance run at $(date) <<<"
    local dockerrunargs=
    docker-jmeter_run_args dockerrunargs # By nameref

    echo "${dockerrunargs[@]}"
    echo docker run ${dockerrunargs[@]} ${jmeterruncmd[@]}
    docker run "${dockerrunargs[@]}" ${jmeterruncmd[@]} | tee "${runoutput}"
    EXITCODE=$?

    # Grep the logs looking for errors and warnings.
    for errorkey in ERROR WARN; do
      # Also checking that the errorkey is the log entry type.
      if grep $errorkey "${SHAREDDIR}/output/logs/jmeter.log" | awk '{print $3}' | grep -q $errorkey ; then
        echo "Error: \"$errorkey\" found in jmeter logs, read log file to see the full trace."
        # EXITCODE=1
      fi
    done

    echo "============================================================================"
    echo "== Date: $(date)"
    echo "== Exit code: ${EXITCODE}"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Performance job type teardown.
function performance_teardown() {
    DATADIR="${SHAREDDIR}/output/runs"

    # Ensure DATADIR exists before copying format_rundata.php.
    mkdir -p "${DATADIR}"

    cp "${BASEDIR}/jobtypes/performance/format_rundata.php" "${DATADIR}/format_rundata.php"

    # Check if rundata.php exists (generated by JMeter run).
    if [[ ! -f "${DATADIR}/rundata.php" ]]; then
        echo "Error: rundata.php not found in ${DATADIR}"
        return 1
    fi

    docker run \
        -v "${DATADIR}:/shared" \
        -w /shared \
        php:8.3-cli \
        php "/shared/format_rundata.php" "rundata.php"

    echo "Storing data with a git commit of '${GIT_COMMIT}'"

    # Resolve absolute target path (use WORKSPACE for relative TARGET_FILE)
    if [[ "${TARGET_FILE}" = /* ]]; then
        targetpath="${TARGET_FILE}"
    else
        targetpath="${WORKSPACE}/${TARGET_FILE}"
    fi

    targetdir="$(dirname "${targetpath}")"
    mkdir -p "${targetdir}"
    cp -f "${DATADIR}/rundata.json" "${targetpath}"
}


# Calculate the command to run for Performance main execution,
# returning it in the passed array parameter.
# Parameters:
#   $1: The array to store the command.
function performance_main_command() {
    local -n _cmd=$1 # Return by nameref.

    # Include logs string.
    includelogs=1
    includelogsstr="-Jincludelogs=$includelogs"
    samplerinitstr="-Jbeanshell.listener.init=recorderfunctions.bsf"


    # TODO: Get all of these values from somewhere?
    # In particular where to get users, loops, rampup, and throughput from?
    # Build the complete perf command for the run.
        _cmd=(
            -n \
            -j "/shared/output/logs/jmeter.log" \
            -t "$testplanfile" \
            -Jusersfile="$testusersfile" \
            -Jgroup="$group" \
            -Jdesc="$description" \
            -Jsiteversion="$siteversion" \
            -Jsitebranch="$sitebranch" \
            -Jsitecommit="$sitecommit" \
            -Jusers=5 -Jloops=1 -Jrampup=1 -Jthroughput=120 \
            $samplerinitstr $includelogsstr
        )
}

function perfomance_testsite_generator_command() {
    local -n _cmd=$1 # Return by nameref.

    # Build the complete perf command for the run.
    _cmd=(
        php admin/tool/generator/cli/maketestsite.php \
            --size="${SITESIZE}" \
            --fixeddataset \
            --bypasscheck \
            --filesizelimit="1000"
    )
}
