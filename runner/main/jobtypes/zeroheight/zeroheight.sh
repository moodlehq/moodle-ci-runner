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

# ZeroHeight job type functions.

# ZeroHeight needed variables to go to the env file.
# The Node.js container does not need a PHP/database env file, so this is empty.
function zeroheight_to_env_file() {
    local env=(
      ZEROHEIGHT_CLIENT_ID
      ZEROHEIGHT_ACCESS_TOKEN
    )
    echo "${env[@]}"
}

# This job type defines the following env variables
function zeroheight_env() {
    env=(
        EXITCODE
    )
    echo "${env[@]}"
}

# ZeroHeight needed modules. Note that the order is important.
# No docker-php, docker-database, moodle-core-copy or summary needed —
# ZeroHeight is a pure JavaScript test runner that only requires Node.js.
function zeroheight_modules() {
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

# ZeroHeight job type checks.
function zeroheight_check() {
    # Check all module dependencies.
    verify_modules $(zeroheight_modules)

    # These env variables must be set for the job to work.
    verify_env UUID NODESERVER
}

# ZeroHeight job type config.
function zeroheight_config() {
    # Apply some defaults.
    EXITCODE=0
}

# ZeroHeight job type setup.
function zeroheight_setup() {
    # Print the run summary (replaces the summary module, which requires docker-php).
    echo "============================================================================"
    echo "= ZeroHeight Job summary <<<"
    echo "============================================================================"
    echo "== JOBTYPE: ${JOBTYPE}"
    echo "== Build Id: ${BUILD_ID}"
    echo "== Code directory: ${CODEDIR}"
    echo "== Shared directory: ${SHAREDDIR}"
    echo "== UUID / Container suffix: ${UUID}"
    echo "== GIT commit: ${GIT_COMMIT}"
    echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
    echo "== Node version: ${NODE_VERSION}"
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
    echo ">>> startsection Initialising ZeroHeight environment at $(date) <<<"
    echo "============================================================================"
    docker exec -t "${NODESERVER}" npm install

    # Install @zeroheight/adoption-cli
    docker exec -t "${NODESERVER}" npm install --no-save @zeroheight/adoption-cli

    docker cp "${BASEDIR}/jobtypes/zeroheight/run.sh" "${NODESERVER}":/tmp/run.sh
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# ZeroHeight job type run.
function zeroheight_run() {
    echo
    echo ">>> startsection Starting ZeroHeight run at $(date) <<<"
    echo "============================================================================"

    docker exec -t \
        "${NODESERVER}" /tmp/run.sh
    EXITCODE=$?

    echo "============================================================================"
    echo ">>> stopsection <<<"
}
