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

# PHPUnit job type functions.

# PHPUnit needed variables to go to the env file.
function phpunit_to_env_file() {
    local env=(
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

        REDISTESTNAME
        MEMCACHED1TESTURL
        MEMCACHED2TESTURL
        MONGODBTESTURL

        EXTTESTURL
        LDAPTESTURL
        SOLRTESTNAME

        MLBACKENDTESTNAME

        MOODLE_CONFIG
    )
    echo "${env[@]}"
}

# PHPUnit information to be added to the summary.
function phpunit_to_summary() {
    echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
    echo "== PHP version: ${PHP_VERSION}"
    echo "== DBTYPE: ${DBTYPE}"
    echo "== DBTAG: ${DBTAG}"
    echo "== DBCOLLATION: ${DBCOLLATION}"
    echo "== DBREPLICAS: ${DBREPLICAS}"
    echo "== MLBACKEND_PYTHON_VERSION: ${MLBACKEND_PYTHON_VERSION}"
    echo "== RUNCOUNT: ${RUNCOUNT}"
    echo "== PHPUNIT_FILTER: ${PHPUNIT_FILTER}"
    echo "== PHPUNIT_TESTSUITE: ${PHPUNIT_TESTSUITE}"
    echo "== MOODLE_CONFIG: ${MOODLE_CONFIG}"
    if [[ -n "${GOOD_COMMIT}" ]] || [[ -n "${BAD_COMMIT}" ]]; then
        echo "== GOOD_COMMIT: ${GOOD_COMMIT}"
        echo "== BAD_COMMIT: ${BAD_COMMIT}"
    fi
}

# This job type defines the following env variables
function phpunit_env() {
    env=(
        RUNCOUNT
        PHPUNIT_FILTER
        PHPUNIT_TESTSUITE
        EXITCODE
    )
    echo "${env[@]}"
}

# PHPUnit needed modules. Note that the order is important.
function phpunit_modules() {
    local modules=(
        env
        summary
        docker
        docker-logs
        git
        plugins
        docker-database
        docker-mocks
        docker-caches
        docker-exttests
        docker-ldap
        docker-solr
        docker-mlbackend
        docker-php
        moodle-config
        moodle-core-copy
        docker-healthy
        docker-summary
    )
    echo "${modules[@]}"
}

# PHPUnit job type checks.
function phpunit_check() {
    # Check all module dependencies.
    verify_modules $(phpunit_modules)

    # These env variables must be set for the job to work.
    verify_env UUID ENVIROPATH WEBSERVER GOOD_COMMIT BAD_COMMIT
}

# PHPUnit job type init.
function phpunit_config() {
    # Apply some defaults.
    RUNCOUNT="${RUNCOUNT:-1}"
    PHPUNIT_FILTER="${PHPUNIT_FILTER:-}"
    PHPUNIT_TESTSUITE="${PHPUNIT_TESTSUITE:-}"
    EXITCODE=0

    # If GOOD_COMMIT and BAD_COMMIT are set, it means that we are going to run a bisect
    # session, so we need to enable FULLGIT (to get access to complete repository clone).
    if [[ -n "${GOOD_COMMIT}" ]] && [[ -n "${BAD_COMMIT}" ]]; then
        FULLGIT="yes"
        # Also, we don't want to allow repetitions in the bisect session.
        RUNCOUNT=1
    fi
}

# PHPUnit job type setup.
function phpunit_setup() {
    # If both GOOD_COMMIT and BAD_COMMIT are not set, we are going to run a normal session.
    # (for bisect sessions we don't have to setup the environment).
    if [[ -z "${GOOD_COMMIT}" ]] && [[ -z "${BAD_COMMIT}" ]]; then
        phpunit_setup_normal
    fi
}

# PHPUnit job type setup for normal mode.
function phpunit_setup_normal() {
    # Init the PHPUnit site.
    echo
    echo ">>> startsection Initialising PHPUnit environment at $(date)<<<"
    echo "============================================================================"
    local initcmd
    phpunit_initcmd initcmd # By nameref.
    docker exec -t -u www-data "${WEBSERVER}" "${initcmd[@]}"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Returns (by nameref) an array with the command needed to init the PHPUnit site.
function phpunit_initcmd() {
    local -n cmd=$1
    cmd=(
        php
        ${PUBLICROOT}admin/tool/phpunit/cli/init.php
    )
}

# PHPUnit job type run.
function phpunit_run() {
    # If both GOOD_COMMIT and BAD_COMMIT are not set, we are going to run a normal session.
    if [[ -z "${GOOD_COMMIT}" ]] && [[ -z "${BAD_COMMIT}" ]]; then
        phpunit_run_normal
    else
        # If GOOD_COMMIT and BAD_COMMIT are set, we are going to run a bisect session.
        phpunit_run_bisect
    fi
}

# PHPUnit job tye run for normal mode.
function phpunit_run_normal() {
    # Run the job type.
    echo
    if [[ RUNCOUNT -gt 1 ]]; then
        echo ">>> startsection Starting ${RUNCOUNT} PHPUnit runs at $(date) <<<"
    else
        echo ">>> startsection Starting PHPUnit run at $(date) <<<"
    fi
    echo "============================================================================"
    # Build the complete command
    local runcmd
    phpunit_runcmd runcmd # By nameref.

    echo "Running: ${runcmd[*]}"

    # Run the command RUNCOUNT times.
    local iter=1
    while [[ ${iter} -le ${RUNCOUNT} ]]; do
        echo
        echo ">>> PHPUnit run ${iter} at $(date) <<<"
        docker exec -t -u www-data "${WEBSERVER}" "${runcmd[@]}"
        EXITCODE=$((EXITCODE + $?))
        iter=$((iter+1))
    done

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# PHPUnit job tye run for bisect mode.
function phpunit_run_bisect() {
    # Run the job type.
    echo
    echo ">>> startsection Starting PHPUnit bisect session at $(date) <<<"
    echo "=== Good commit: ${GOOD_COMMIT}"
    echo "=== Bad commit: ${BAD_COMMIT}"
    echo "============================================================================"
    # Start the bisect session.
    docker exec -t -u www-data "${WEBSERVER}" \
        git bisect start "${BAD_COMMIT}" "${GOOD_COMMIT}"

    # Build the int command.
    local initcmd
    phpunit_initcmd initcmd # By nameref.

    # Build the run command.
    local runcmd
    phpunit_runcmd runcmd # By nameref.

    # Generate the bisect.sh script that we are going to use to run the phpunit bisect session.
    # (it runs both init and run commands together).
    docker exec -i -u www-data "${WEBSERVER}" \
        bash -c "cat > bisect.sh" <<- EOF
			#!/bin/bash
			${initcmd[@]} >/dev/null 2>&1; ${runcmd[@]}
			exitcode=\$?
			echo "============================================================================"
			exit \$exitcode
			EOF

    # Run the bisect session.
    echo "============================================================================"
    docker exec -u www-data "${WEBSERVER}" \
        git bisect run bash bisect.sh
    EXITCODE=$?

    # Print the bisect logs, for the records.
    echo
    echo "============================================================================"
    echo "Bisect logs and reset:"
    docker exec -u www-data "${WEBSERVER}" \
        git bisect log

    # Finish the bisect session.
    docker exec -u www-data "${WEBSERVER}" \
        git bisect reset

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Returns (by nameref) an array with the command needed to run the PHPUnit tests.
function phpunit_runcmd() {
    local -n cmd=$1
    cmd=(
        php
        vendor/bin/phpunit
        --disallow-test-output
        --fail-on-risky
        --log-junit /shared/log.junit
    )
    if [[ -n "${PHPUNIT_FILTER}" ]]; then
        cmd+=(--filter "${PHPUNIT_FILTER}")
    fi
    if [[ -n "${PHPUNIT_TESTSUITE}" ]]; then
        cmd+=(--testsuite "${PHPUNIT_TESTSUITE}")
    fi
}
