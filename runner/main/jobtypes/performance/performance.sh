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
        JOBTYPE
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
    echo "== PERF_USERS: ${PERF_USERS}"
    echo "== PERF_LOOPS: ${PERF_LOOPS}"
    echo "== PERF_RAMPUP: ${PERF_RAMPUP}"
    echo "== PERF_THROUGHPUT: ${PERF_THROUGHPUT}"
    echo "== TARGET_FILE: ${TARGET_FILE}"
}

# This job type defines the following env variables
function performance_env() {
    env=(
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
    verify_env UUID WORKSPACE SHAREDDIR ENVIROPATH WEBSERVER
}

# Performance job type init.
function performance_config() {
    EXITCODE=0

    export MOODLE_WWWROOT="http://${WEBSERVER}"
    export SITESIZE="${SITESIZE:-XS}"
    export COURSENAME="performance_course"

    # Default target file (relative to WORKSPACE) where rundata.json will be stored.
    export TARGET_FILE="${TARGET_FILE:-storage/performance/${MOODLE_BRANCH}/rundata.json}"

    # Derive JMeter run parameters from SITESIZE.
    # These arrays match the ones in the generator.php plugin and Moodle core.
    #                    XS  S    M     L      XL      XXL
    local -a _users=(    1   30   100   1000   5000    10000 )
    local -a _loops=(    5   5    5     6      6       7     )
    local -a _rampups=(  1   6    40    100    500     800   )
    local -a _throughput=(120 120  120   120    120     120   )

    local sizeindex
    sizeindex=$(performance_size_to_index "${SITESIZE}")

    export PERF_USERS="${_users[$sizeindex]}"
    export PERF_LOOPS="${_loops[$sizeindex]}"
    export PERF_RAMPUP="${_rampups[$sizeindex]}"
    export PERF_THROUGHPUT="${_throughput[$sizeindex]}"
}

# Convert a SITESIZE name (XS, S, M, L, XL, XXL) to a numeric index (0-5).
function performance_size_to_index() {
    local size="${1:-XS}"
    case "${size}" in
        XS)  echo 0 ;;
        S)   echo 1 ;;
        M)   echo 2 ;;
        L)   echo 3 ;;
        XL)  echo 4 ;;
        XXL) echo 5 ;;
        *)   echo 0 ;; # Default to XS.
    esac
}

# Performance job type setup for normal mode.
function performance_setup() {
    # Init the Performance site.
    echo
    echo ">>> startsection Initialising Performance environment at $(date)<<<"
    echo "============================================================================"

    # Ensure host shared directories exist and are writable so plugin can save files.
    # Note: runs_samples is needed by the JMeter SimpleDataWriter in the test plan.
    mkdir -p "${SHAREDDIR}/output/logs" "${SHAREDDIR}/output/runs" "${SHAREDDIR}/runs_samples"
    chmod -R 2777 "${SHAREDDIR}"

    # Run the moodle install_database.php.
    local initcmd
    performance_initcmd initcmd # By nameref.
    echo "Running: ${initcmd[*]}"
    docker exec -t -u www-data "${WEBSERVER}" "${initcmd[@]}"

    # Generate the test data and plan files using the local_performancetool.
    local perftoolcmd
    performance_perftoolcmd perftoolcmd
    docker exec -t -u www-data "${WEBSERVER}" "${perftoolcmd[@]}"

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Performance job type run.
function performance_run() {

    echo ">>> startsection Starting Performance main run at $(date) <<<"
    echo "============================================================================"

    datestring=`date '+%Y%m%d%H%M'`

    # Get the plan file name.
    testplanfile=`ls "${SHAREDDIR}"/*.jmx | head -1 | sed "s@${SHAREDDIR}@/shared@"`
    echo "Using test plan file: ${testplanfile}"

    # Get the users file name.
    testusersfile=`ls "${SHAREDDIR}"/*.csv | head -1 | sed "s@${SHAREDDIR}@/shared@"`
    echo "Using test users file: ${testusersfile}"

    group="${MOODLE_BRANCH}"
    description="${GIT_COMMIT}"
    siteversion="${MOODLE_BRANCH}"
    sitebranch="${MOODLE_BRANCH}"
    sitecommit="${GIT_COMMIT}"
    runoutput="${SHAREDDIR}/output/logs/run.log"

    # Calculate the command to run for Performance, returning it in the passed array parameter.
    local jmeterruncmd=
    performance_main_command jmeterruncmd

    # Get the docker run args for the jmeter container.
    local dockerrunargs=
    docker-jmeter_run_args dockerrunargs

    echo ">>> Performance run at $(date) <<<"
    docker run "${dockerrunargs[@]}" ${jmeterruncmd[@]} | tee "${runoutput}"
    EXITCODE=$?

    # Grep the JMeter logs for genuine errors.
    # We only check for ERROR-level entries. WARN entries are expected and harmless
    # (e.g. CookieManager superseded, StatusConsoleListener deprecation notices).
    if grep -q ' ERROR ' "${SHAREDDIR}/output/logs/jmeter.log" 2>/dev/null; then
        echo "WARNING: ERROR entries found in jmeter.log — check the log for details."
        echo "  (This is informational and does not fail the build by itself.)"
    fi

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

    # Format the rundata.php into a more usable JSON format, using the provided PHP script.
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

    # Ensure the target directory exists.
    targetdir="$(dirname "${targetpath}")"
    mkdir -p "${targetdir}"

    # Copy the formatted rundata.json to the target path.
    echo "Copying formatted rundata.json to ${targetpath}"
    cp -f "${DATADIR}/rundata.json" "${targetpath}"

    # Note: Regression detection (comparison of before/after runs) is handled externally
    # by the moodle-bench-diff tool, invoked from the nightlyjobs pipeline after both
    # Test Run A and Test Run B complete. See runPerformanceTask.groovy.
}

# Returns the command to install the performance site.
function performance_initcmd() {
    local -n cmd=$1

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

# Returns the command to generate the required test data in the performance site.
function performance_perftoolcmd() {
    local -n cmd=$1

    # Build the complete command to generate test data and plan files.
    # Note: --bypasscheck is needed because CI may not have debugdeveloper set at the point
    #       where the generator checks it. --quiet is intentionally omitted to see progress output.
    # Note: --updateuserspassword ensures the users' passwords in the database match the
    #       password written to the CSV ($CFG->tool_generator_users_password), which is
    #       critical for JMeter to be able to login as those users.
    cmd=(
        php public/local/performancetool/generate_test_data.php \
            --size="${SITESIZE}" \
            --planfilespath="/shared" \
            --bypasscheck \
            --updateuserspassword
    )
}

# Calculate the command to run for Performance main execution, returning it in the passed array parameter.
# Parameters:
#   $1: The array to store the command.
function performance_main_command() {
    local -n _cmd=$1

    # Include logs string.
    includelogs=1
    includelogsstr="-Jincludelogs=$includelogs"
    samplerinitstr="-Jbeanshell.listener.init=recorderfunctions.bsf"

    # Users, loops, rampup, and throughput are derived from SITESIZE in performance_config().
    # They match the arrays baked into generator.php and the JMX template defaults.
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
        -Jusers="${PERF_USERS}" \
        -Jloops="${PERF_LOOPS}" \
        -Jrampup="${PERF_RAMPUP}" \
        -Jthroughput="${PERF_THROUGHPUT}" \
        $samplerinitstr $includelogsstr
    )
}
