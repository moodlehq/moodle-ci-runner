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

# Docker Node.js module functions.

# This module defines the following env variables.
function docker-node_env() {
    env=(
        NODE_VERSION
        DOCKER_NODE
        NODESERVER
    )
    echo "${env[@]}"
}

# Docker Node module checks.
function docker-node_check() {
    # Check all module dependencies.
    verify_modules docker env

    # These env variables must be set for the module to work.
    verify_env NETWORK UUID SHAREDDIR
}

# Docker Node module config.
function docker-node_config() {
    # Apply some defaults.
    NODE_VERSION="${NODE_VERSION:-22}"
    DOCKER_NODE="${DOCKER_NODE:-node:${NODE_VERSION}}"
    NODESERVER="nodeserver${UUID}"
}

# Docker Node module setup, start the Node.js container.
function docker-node_setup() {
    echo ">>> startsection Starting Node.js container <<<"
    echo "============================================================================"

    docker run \
      --network "${NETWORK}" \
      --name "${NODESERVER}" \
      --detach \
      --env-file "${ENVIROPATH}" \
      --workdir /app \
      -v "${SHAREDDIR}":/shared \
      "${DOCKER_NODE}" \
      tail -f /dev/null

    echo
    echo "Node.js container logs:"
    docker logs "${NODESERVER}"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

