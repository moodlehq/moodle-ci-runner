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
        MOODLE_CONFIG
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

    # Create an empty timing file.
    touch "${SHAREDDIR}"/timing.json

    # Clone the moodle-performance-comparison repository.
    git clone https://github.com/moodlehq/moodle-performance-comparison.git

    # Set up the environment.
    cd moodle-performance-comparison
    composer install

    # Pull the JMeter Docker image.
    docker pull justb4/jmeter

    # Run the JMeter container.
    docker run -d --name jmeter-container justb4/jmeter

    # Init the Performance site.
    echo
    echo ">>> startsection Initialising Performance environment at $(date)<<<"
    echo "============================================================================"
    local initcmd
    performance_initcmd initcmd # By nameref.

    echo "Running: ${initcmd[*]}"

    docker exec -t -u www-data "${WEBSERVER}" "${initcmd[@]}"
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
        php admin/cli/install_database.php --agree-license --fullname="Moodle Performance Test" --shortname="moodle" --adminuser=admin --adminpass=adminpass --
    )
}

#function performance_datacmd() {
#
#}

# Performance job type run.
function performance_run() {
    performance_run_normal
}

# PHPUnit job tye run for normal mode.
function performance_run_normal() {    # Run the job type.
    echo
    if [[ RUNCOUNT -gt 1 ]]; then
        echo ">>> startsection Starting ${RUNCOUNT} Performance main runs at $(date) <<<"
    else
        echo ">>> startsection Starting Performance main run at $(date) <<<"
    fi
    echo "============================================================================"

    # Calculate the command to run. The function will return the command in the passed array.
    local cmd=
    performance_main_command cmd

    echo "Running: ${cmd[*]}"

    # Run the command "RUNCOUNT" times.
    local iter=1
    while [[ ${iter} -le ${RUNCOUNT} ]]; do
        echo
        echo ">>> Performance run ${iter} at $(date) <<<"
        docker exec -t -u www-data "${WEBSERVER}" "${cmd[@]}"
        EXITCODE=$((EXITCODE + $?))
        iter=$((iter+1))
    done

    echo "============================================================================"
    echo "== Date: $(date)"
    echo "== Main run exit code: ${EXITCODE}"
    echo "============================================================================"
    echo ">>> stopsection <<<"

    # If the main run passed, we are done.
    if [[ "${EXITCODE}" -eq 0 ]]; then
        return
    fi
}

# Performance job type teardown.
function performance_teardown() {
    # Need to copy the updated timing file back to the workspace.
    cp "${SHAREDDIR}"/timing.json "${timingpath}"
}

# Calculate the command to run for Performance main execution,
# returning it in the passed array parameter.
# Parameters:
#   $1: The array to store the command.
function performance_main_command() {
    local -n _cmd=$1 # Return by nameref.

    # Let's build the complete perf command for the 1st (parallel) run.
    _cmd=(
        php admin/tool/perf/cli/run.php
    )

    # Add the options and profile.
    _cmd+=("${options[@]}")
    _cmd+=("${profile[@]}")
}

