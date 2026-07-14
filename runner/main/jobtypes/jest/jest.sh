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

# Jest job type functions.

# Jest needed variables to go to the env file.
# The Node.js container does not need a PHP/database env file, so this is empty.
function jest_to_env_file() {
    local env=()
    echo "${env[@]}"
}

# This job type defines the following env variables
function jest_env() {
    env=(
        JEST_FILTER
        EXITCODE
    )
    echo "${env[@]}"
}

# Jest needed modules. Note that the order is important.
# No docker-php, docker-database, moodle-core-copy or summary needed —
# Jest is a pure JavaScript test runner that only requires Node.js.
function jest_modules() {
    local modules=(
        env
        moodle-branch
        docker
        docker-logs
        git
        docker-node
        docker-healthy
        docker-summary
    )
    echo "${modules[@]}"
}

# Jest job type checks.
function jest_check() {
    # Check all module dependencies.
    verify_modules $(jest_modules)

    # These env variables must be set for the job to work.
    verify_env UUID NODESERVER
}

# Jest job type config.
function jest_config() {
    # Apply some defaults.
    JEST_FILTER="${JEST_FILTER:-}"
    EXITCODE=0
}

# Jest job type setup.
function jest_setup() {
    # Print the run summary (replaces the summary module, which requires docker-php).
    echo "============================================================================"
    echo "= Jest Job summary <<<"
    echo "============================================================================"
    echo "== JOBTYPE: ${JOBTYPE}"
    echo "== Build Id: ${BUILD_ID}"
    echo "== Code directory: ${CODEDIR}"
    echo "== Shared directory: ${SHAREDDIR}"
    echo "== UUID / Container suffix: ${UUID}"
    echo "== GIT commit: ${GIT_COMMIT}"
    echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
    echo "== Node version: ${NODE_VERSION}"
    echo "== JEST_FILTER: ${JEST_FILTER}"
    echo "============================================================================"

    # Copy the Moodle source code into the Node.js container.
    echo
    echo ">>> startsection Copying source files into Node.js container at $(date) <<<"
    echo "============================================================================"
    docker cp "${CODEDIR}"/. "${NODESERVER}":/app
    echo "============================================================================"
    echo ">>> stopsection <<<"

    # Install Node.js dependencies.
    echo
    echo ">>> startsection Initialising Jest environment at $(date) <<<"
    echo "============================================================================"
    docker exec -t "${NODESERVER}" npm install
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Jest job type run.
function jest_run() {
    echo
    echo ">>> startsection Starting Jest run at $(date) <<<"
    echo "============================================================================"

    # Build the complete command.
    local runcmd
    jest_runcmd runcmd # By nameref.

    echo "Running: ${runcmd[*]}"
    echo

    docker exec -t "${NODESERVER}" "${runcmd[@]}"
    EXITCODE=$?

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Returns (by nameref) an array with the command needed to run the Jest tests.
function jest_runcmd() {
    local -n cmd=$1
    cmd=(npm test)
    if [[ -n "${JEST_FILTER}" ]]; then
        cmd+=(-- --passWithNoTests "${JEST_FILTER}")
    fi
}
