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

# Caches module functions.

# This module defines the following env variables.
function docker-caches_env() {
    env=(
        REDISTESTNAME
        MEMCACHED1TESTURL
        MEMCACHED2TESTURL
        MONGODBTESTURL
    )
    echo "${env[@]}"
}

# Caches module checks.
function docker-caches_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the database module to work.
    verify_env NETWORK UUID
}

# Caches module config.
function docker-caches_config() {
    # Apply some defaults.
    REDISTESTNAME=redis"${UUID}"
    MEMCACHED1TESTURL=memcached1"${UUID}"
    MEMCACHED2TESTURL=memcached2"${UUID}"
    MONGODB=mongodb"${UUID}"
    MONGODBTESTURL="mongodb://${MONGODB}:27017"
}

# Caches module setup, launch the containers.
function docker-caches_setup() {
    echo
    echo ">>> startsection Starting caching services <<<"
    echo "============================================================================"

    # Start the Redis server.
    docker run \
        --detach \
        --name "${REDISTESTNAME}" \
        --network "${NETWORK}" \
    redis:5
    echo "Redis URL: ${REDISTESTNAME}"
    echo "Redis logs:"
    docker logs "${REDISTESTNAME}"

    echo

    # Start the Memcached servers
    docker run \
        --detach \
        --name "${MEMCACHED1TESTURL}" \
        --network "${NETWORK}" \
    memcached:1.4
    echo "Memcached 1 URL: ${MEMCACHED1TESTURL}"
    echo "Memcached 1 logs:"
    docker logs "${MEMCACHED1TESTURL}"

    echo

    docker run \
        --detach \
        --name "${MEMCACHED2TESTURL}" \
        --network "${NETWORK}" \
    memcached:1.4
    echo "Memcached 2 URL: ${MEMCACHED2TESTURL}"
    echo "Memcached 2 logs:"
    docker logs "${MEMCACHED2TESTURL}"

    echo

    # TODO: We only need this for Moodle <= 4.1 (401). See MDL-77163.
    docker run \
        --detach \
        --name "${MONGODB}" \
        --network "${NETWORK}" \
        mongo:4.0
    echo "MongoDB URL: ${MONGODBTESTURL}"
    echo "MongoDB logs:"
    docker logs "${MONGODB}"

    echo "============================================================================"
    echo ">>> stopsection <<<"
}
