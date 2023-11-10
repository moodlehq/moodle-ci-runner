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

# App (ionic) module functions.

# This module defines the following env variables.
function docker-ionic_env() {
    env=(
        MOBILE_VERSION
        MOBILE_APP_PORT
        IONIC
        IONICURL
    )
    echo "${env[@]}"
}

# Ionic module checks.
function docker-ionic_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the database module to work.
    verify_env NETWORK UUID BROWSER
}

# Ionic module config.
function docker-ionic_config() {
    # Apply some defaults.
    MOBILE_VERSION="${MOBILE_VERSION:-}" # Required to launch the app container.
    MOBILE_APP_PORT="${MOBILE_APP_PORT:-80}"

    # If MOBILE_VERSION is not defined or the current browser is not "chrome" we are done.
    if [[ -z ${MOBILE_VERSION} ]] || [[ ${BROWSER} != "chrome" ]]; then
        return
    fi
    IONIC="ionic${UUID}"
    IONICURL="http://${IONIC}:${MOBILE_APP_PORT}"
}

# Ionic module setup, launch the containers.
function docker-ionic_setup() {
    # If IONICURL is empty, we are done.
    if [[ -z ${IONICURL} ]]; then
        return
    fi

    # Arrived here, let's launch the app container and setup IONICURL.
    echo
    echo ">>> startsection Starting Ionic app <<<"
    echo "============================================================================"

    docker run \
        --detach \
        --name "${IONIC}" \
        --network "${NETWORK}" \
        moodlehq/moodleapp:"${MOBILE_VERSION}"
    echo "Ionic app url: ${IONICURL}"
    echo "Ionic app logs:"
    docker logs "${IONIC}"

    echo "============================================================================"
    echo ">>> stopsection <<<"
}
