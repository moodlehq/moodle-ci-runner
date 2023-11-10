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

# Solr module functions.

# This module defines the following env variables.
function docker-solr_env() {
    env=(
        SOLRTESTNAME
    )
    echo "${env[@]}"
}

# Solr module checks.
function docker-solr_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the database module to work.
    verify_env NETWORK UUID
}

# Solr module config.
function docker-solr_config() {
    # Apply some defaults.
    SOLRTESTNAME=solr"${UUID}"
}

# Solr module setup, launch the containers.
function docker-solr_setup() {
    echo
    echo ">>> startsection Starting Solr server <<<"
    echo "============================================================================"

    # Start the solr server
    docker run \
        --detach \
        --name "${SOLRTESTNAME}" \
        --network "${NETWORK}" \
        solr:7 \
        solr-precreate test
    echo "Solr: URL: ${SOLRTESTNAME}"
    echo "Solr logs:"
    docker logs "${SOLRTESTNAME}"

    echo "============================================================================"
    echo ">>> stopsection <<<"
}
