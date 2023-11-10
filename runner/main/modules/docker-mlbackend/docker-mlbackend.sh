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

# Python ML backend module functions.

# This module defines the following env variables.
function docker-mlbackend_env() {
    env=(
        MLBACKENDTESTNAME
    )
    echo "${env[@]}"
}

# Python ML backend module checks.
function docker-mlbackend_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the database module to work.
    verify_env NETWORK UUID
}

# Python ML backend config.
function docker-mlbackend_config() {
    # Apply some defaults.
    MLBACKEND_PYTHON_VERSION=${MLBACKEND_PYTHON_VERSION:-}
    if [[ -n "${MLBACKEND_PYTHON_VERSION}" ]]; then
        # Only if it has been explicitly requested.
        MLBACKENDTESTNAME=mlpython"${UUID}"
    fi
}

# Python ML backend module setup, launch the containers.
function docker-mlbackend_setup() {
    # Only if it has been explicitly requested.
    if [[ -n "${MLBACKEND_PYTHON_VERSION}" ]]; then
        echo
        echo ">>> startsection Starting Python ML backend server <<<"
        echo "============================================================================"

        # Start the Python ML backend server.
        docker run \
          --detach \
          --name "${MLBACKENDTESTNAME}" \
          --network "${NETWORK}" \
          moodlehq/moodle-mlbackend-python:"${MLBACKEND_PYTHON_VERSION}"
        echo "Python ML backend: URL: ${MLBACKENDTESTNAME}"
        echo "Python ML backend logs:"
        docker logs "${MLBACKENDTESTNAME}"

        echo "============================================================================"
        echo ">>> stopsection <<<"
    else
        echo "Python ML backend server not requested."
    fi
}
