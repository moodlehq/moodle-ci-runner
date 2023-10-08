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

# Mocks module functions.

# This module defines the following env variables.
function docker-mocks_env() {
    env=(
        BBBMOCKURL
        MATRIXMOCKURL
    )
    echo "${env[@]}"
}

# Mocks module checks.
function docker-mocks_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the database module to work.
    verify_env NETWORK UUID
}

# Mocks module config.
function docker-mocks_config() {
    # Apply some defaults.
    BBBMOCK="bbbmock${UUID}"
    BBBMOCKURL="http://${BBBMOCK}"

    MATRIXMOCK="matrixmock${UUID}"
    MATRIXMOCKURL="http://${MATRIXMOCK}"
}

# Mocks module setup, launch the mock containers.
function docker-mocks_setup() {
    echo
    echo ">>> startsection Starting mocking services <<<"
    echo "============================================================================"

    # Start the BigBlueButton mock.
    docker run \
        --detach \
        --name "${BBBMOCK}" \
        --network "${NETWORK}" \
        moodlehq/bigbluebutton_mock:latest
    echo "BBB mock url: ${BBBMOCKURL}"
    echo "BBB mock logs:"
    docker logs "${BBBMOCK}"

    echo

    # Start the Matrix mock.
    docker run \
      --detach \
      --name "${MATRIXMOCK}" \
      --network "${NETWORK}" \
      moodlehq/matrixsynapse_mock:latest
    echo "Matrix mock url: ${MATRIXMOCKURL}"
    echo "Matrix mock logs:"
    docker logs "${MATRIXMOCK}"

    echo "============================================================================"
    echo ">>> stopsection <<<"
}