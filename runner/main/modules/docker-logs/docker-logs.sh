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

# Docker logs module functions.

# This module defines the following env variables.
function docker-logs_env() {
    env=()
    echo "${env[@]}"
}

# Docker logs module checks.
function docker-logs_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the module to work.
    verify_env UUID SHAREDDIR
}

# Docker logs module teardown. Let's copy all the containers logs to the shared dir.
function docker-logs_teardown() {
    echo ">>> startsection Exporting docker logs<<<"
    echo "============================================================================"
    echo "Exporting all docker logs for UUID: ${UUID}"
    # Store the docker container logs.
    for container in $(docker ps -a --format "{{.ID}}~{{.Names}}" --filter name="${UUID}"); do
        image=$(echo "${container}" | cut -d'~' -f1)
        name=$(echo "${container}" | cut -d'~' -f2)
        name=${name%"${UUID}"} # Get rid of the UUID for naming log files.
        echo "  - ${name} logs to ${SHAREDDIR}/${name}.gz"
        docker logs "${image}" 2>&1 | gzip > "${SHAREDDIR}/${name}.gz"
    done

# TODO: Why do we need this?
# Only if the container exists and is running.
if [[ -n $(docker ps --filter name="${WEBSERVER}" --filter status=running --quiet) ]]; then
    docker exec -t "${WEBSERVER}" \
        chown -R "${UID}:${GROUPS[0]}" /shared
fi

echo "============================================================================"
echo ">>> stopsection <<<"
}