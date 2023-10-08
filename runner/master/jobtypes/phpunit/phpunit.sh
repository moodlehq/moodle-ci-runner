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
    verify_env UUID ENVIROPATH WEBSERVER
}

# PHPUnit job type init.
function phpunit_config() {
    # Apply some defaults.
    RUNCOUNT="${RUNCOUNT:-1}"
    PHPUNIT_FILTER="${PHPUNIT_FILTER:-}"
    PHPUNIT_TESTSUITE="${PHPUNIT_TESTSUITE:-}"
    EXITCODE=0
}

# PHPUnit job type setup.
function phpunit_setup() {
    # Init the PHPUnit site.
    echo
    echo ">>> startsection Initialising PHPUnit environment at $(date)<<<"
    echo "============================================================================"
    docker exec -t -u www-data "${WEBSERVER}" \
        php admin/tool/phpunit/cli/init.php \
            --force
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# PHPUnit job type run.
function phpunit_run() {
    # Run the job type.
    echo
    if [[ RUNCOUNT -gt 1 ]]; then
        echo ">>> startsection Starting ${RUNCOUNT} PHPUnit runs at $(date) <<<"
    else
        echo ">>> startsection Starting PHPUnit run at $(date) <<<"
    fi
    echo "============================================================================"
    # Build the complete command
    local cmd=(
        php vendor/bin/phpunit
        --disallow-test-output
        --fail-on-risky
        --log-junit /shared/log.junit
        --verbose
    )
    if [[ -n "${PHPUNIT_FILTER}" ]]; then
        cmd+=(--filter "${PHPUNIT_FILTER}")
    fi
    if [[ -n "${PHPUNIT_TESTSUITE}" ]]; then
        cmd+=(--testsuite "${PHPUNIT_TESTSUITE}")
    fi

    echo "Running: ${cmd[*]}"

    # Run the command RUNCOUNT times.
    local iter=1
    while [[ ${iter} -le ${RUNCOUNT} ]]; do
        echo
        echo ">>> PHPUnit run ${iter} at $(date) <<<"
        docker exec -t "${WEBSERVER}" "${cmd[@]}"
        EXITCODE=$((EXITCODE + $?))
        iter=$((iter+1))
    done

    echo "============================================================================"
    echo ">>> stopsection <<<"
}