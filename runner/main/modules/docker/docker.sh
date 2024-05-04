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

# Docker module functions.

# This module defines the following env variables.
function docker_env() {
    env=(
        NETWORK
    )
    echo "${env[@]}"
}

# Docker module checks.
function docker_check() {
    if ! docker --version > /dev/null 2>&1; then
        exit_error "Docker is not installed. Please install it and try again."
    fi

    # These env variables must be set for the module to work.
    verify_env UUID
}

# Docker module config.
function docker_config() {
    # Apply some defaults.
    NETWORK="${NETWORK:-moodle}"
}

# Docker module setup, basically create the network that will be used by all the containers.
function docker_setup() {
    echo ">>> startsection Checking networks <<<"
    echo "============================================================================"
    local networkid=
    networkid=$(docker network list -q --filter name="${NETWORK}$")
    if [[ -z ${networkid} ]]
    then
        echo "Creating new network '${NETWORK}'"
        NETWORK=$(docker network create "${NETWORK}")
    fi
    echo "Found network '${NETWORK}' with identifier ${networkid}"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Docker module teardown, stop and remove all the containers that were used in this run (by UUID).
function docker_teardown() {
    echo ">>> startsection Cleaning up docker containers <<<"
    echo "============================================================================"
    echo "Stopping and removing all docker containers for UUID: ${UUID}"
    docker ps -a --filter name="${UUID}"
    echo
    for container in $(docker ps -a -q --filter name="${UUID}"); do
        echo -n "  - Stopping and removing container "
        docker stop "${container}" | xargs docker rm --volumes
    done
    echo "============================================================================"
    echo ">>> stopsection <<<"
}
