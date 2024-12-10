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

# Ext. tests module functions.

# This module defines the following env variables.
function docker-exttests_env() {
    env=(
        EXTTESTURL
    )
    echo "${env[@]}"
}

# Ext. tests module checks.
function docker-exttests_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the database module to work.
    verify_env NETWORK UUID
}

# Ext. tests module config.
function docker-exttests_config() {
    EXTTESTS=exttests"${UUID}"
    EXTTESTURL="http://${EXTTESTS}"
}

# Ext. tests module setup, launch the containers.
function docker-exttests_setup() {
    echo
    echo ">>> startsection Starting exttests server <<<"
    echo "============================================================================"

    # Start the exttests server
    docker run \
        --detach \
        --name "${EXTTESTS}" \
        --network "${NETWORK}" \
        moodlehq/moodle-exttests:latest
    echo "Ext. tests URL: ${EXTTESTURL}"
    echo "Ext. tests logs:"
    docker logs "${EXTTESTS}"

    echo "============================================================================"
    echo ">>> stopsection <<<"
}
