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

# Locust job type functions.

# Locust needed variables to go to the env file.
function locust_to_env_file() {
    local env=(
        COMPOSERINSTALL
        PHPWORKINGDIR
        PUBLICROOT

        DBTYPE
        DBTAG
        DBHOST
        DBNAME
        DBUSER
        DBPASS
        DBCOLLATION
        DBREPLICAS
        DBHOST_DBREPLICA

        BBBMOCKURL
        MATRIXMOCKURL

        SELENIUMURL_1

        WEBSERVER
        APACHE_DOCUMENT_ROOT
        PUBLICROOT

        BROWSER

        BEHAT_INIT_ARGS

        MOODLE_CONFIG
    )
    echo "${env[@]}"
}

# Locust information to be added to the summary.
function locust_to_summary() {
    echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
    echo "== PHP version: ${PHP_VERSION}"
    echo "== DBTYPE: ${DBTYPE}"
    echo "== DBTAG: ${DBTAG}"
    echo "== DBREPLICAS: ${DBREPLICAS}"
    echo "== RUNCOUNT: ${RUNCOUNT}"
    echo "== BROWSER: ${BROWSER}"
    echo "== BEHAT_SUITE: ${BEHAT_SUITE}"
    echo "== BEHAT_NAME: ${BEHAT_NAME}"
    echo "== BEHAT_PATH: ${BEHAT_PATH}"
    echo "== BEHAT_INIT_ARGS: ${BEHAT_INIT_ARGS}"
    echo "== MOODLE_CONFIG: ${MOODLE_CONFIG}"
    echo "== PHPWORKINGDIR: ${PHPWORKINGDIR}"
    echo "== COMPOSERINSTALL: ${COMPOSERINSTALL}"
    echo "== PLUGINSTOINSTALL: ${PLUGINSTOINSTALL}"
}

# This job type defines the following env variables
function locust_env() {
    env=(
        RUNCOUNT
        BEHAT_SUITE
        BEHAT_NAME
        BEHAT_PATH
        BEHAT_INIT_ARGS
        EXITCODE
    )
    echo "${env[@]}"
}

# Locust needed modules. Note that the order is important.
function locust_modules() {
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
        docker-mocks
        docker-selenium
        docker-ionic
        docker-mlbackend
        docker-php
        moodle-config
        moodle-skip-tag-injector
        moodle-core-copy
        docker-healthy
        docker-summary
        moodle-composer
        moodle-locust
    )
    echo "${modules[@]}"
}

# Locust job type checks.
function locust_check() {
    # Check all module dependencies.
    verify_modules $(locust_modules)

    # These env variables must be set for the job to work.
    verify_env UUID WORKSPACE SHAREDDIR ENVIROPATH WEBSERVER GOOD_COMMIT BAD_COMMIT
}

# Locust job type init.
function locust_config() {
    # Apply some defaults.
    PUBLICROOT="${PUBLICROOT:-}"
    RUNCOUNT="${RUNCOUNT:-1}"
    BEHAT_SUITE="${BEHAT_SUITE:-}"
    BEHAT_NAME="${BEHAT_NAME:-}"
    BEHAT_PATH="${BEHAT_PATH:-}"
    BEHAT_INIT_ARGS="${BEHAT_INIT_ARGS:-}"
    EXITCODE=0
}

# Locust job type setup.
function locust_setup() {
    locust_setup_normal
}

# Locust job type setup for normal mode.
function locust_setup_normal() {
    # Init the Locust site.
    echo
    echo ">>> startsection Initialising Locust environment at $(date)<<<"
    echo "============================================================================"
    local initcmd
    locust_initcmd initcmd # By nameref.

    echo "Running: ${initcmd[*]}"

    docker exec -t -u www-data "${WEBSERVER}" "${initcmd[@]}"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Returns (by nameref) an array with the command needed to init the Locust site.
function locust_initcmd() {
    local -n cmd=$1
    # We need to determine the init suite to use.
    local initsuite=""
    if [[ -n "$BEHAT_SUITE" ]]; then
        initsuite="-a=${BEHAT_SUITE}"
    fi

    # Build the complete init command.
    cmd=(
        php ${PUBLICROOT}admin/tool/locust/cli/init.php
        "${initsuite}"
        -j=1
    )
    if [[ -n "${BEHAT_INIT_ARGS}" ]]; then
        cmd+=( "${BEHAT_INIT_ARGS}")
    fi

    echo ">>> startsection Behat to create the test data at $(date) <<<"
    echo "============================================================================"

    echo "Copy feature"
    FEATUREPATH="${PUBLICROOT}/public/lib/tests/behat/locust.feature"

    docker cp \
      "${WORKSPACE}/moodle-locust-runner/feature/locust.feature" \
      "${WEBSERVER}":"${FEATUREPATH}"

    # Calculate the command to run. The function will return the command in the passed array.
    local cmd= locust_behat_run cmd
    echo "Running: ${cmd[*]}"
    docker exec -t -u www-data "${WEBSERVER}" "${cmd[@]}"
}

# Locust job type run.
function locust_run() {
    echo
    echo ">>> startsection Starting Locust main run at $(date) <<<"
    echo "============================================================================"

    # Calculate the command to run. The function will return the command in the passed array.
    local cmd=
    locust_runcmd cmd

    echo "Running: ${cmd[*]}"

    cd "${WORKSPACE}/moodle-locust-runner/"

    $cmd[@]
    EXITCODE=$?

    echo "============================================================================"
    echo "== Date: $(date)"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

function locust_runcmd() {
    local -n _cmd=#1

    _cmd+=(
      docker compose up
      --build locust
      --headless
      -H "http://${WEBSERVER}"
    )
}


# Calculate the command to run for Locust main execution,
# returning it in the passed array parameter.
# Parameters:
#   $1: The array to store the command.
function locust_behat_run() {
    local -n _cmd=$1 # Return by nameref.

    # Pre-calculate a few format and profile options (they are different for parallel and non-parallel runs).
    local options=(
        --format=moodle_progress --out=std
    )
    local profile=()
    options+=(
        --format=pretty --out=/shared/pretty.txt
        --format=junit --out=/shared/log.junit
    )
    profile+=(
        --profile="${BROWSER}"
    )

    # Let's build the complete locust command for the 1st (parallel) run.
    _cmd=(
        php ${PUBLICROOT}admin/tool/locust/cli/run.php
    )

    # Add the options and profile.
    _cmd+=("${options[@]}")
    _cmd+=("${profile[@]}")
    _cmd+=(public/lib/tests/behat/locust.feature)
}
