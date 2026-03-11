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

# Moodle module functions for Composer-based Moodle installations.

# This module defines the following env variables.
function docker-otel_env() {
    env=(
        COLLECTOR
    )
    echo "${env[@]}"
}

# Moodle composer module checks.
function docker-otel_check() {
    # These env variables must be set for the module to work.
    verify_env CODEDIR
}

# Docker module init.
function docker-otel_config() {
    # Apply some defaults (always set to the minimum version supported in the main branch).
    COLLECTOR=collector"${UUID}"

    OTEL_VERSION="latest"
}

# Moodle composer module config.
function docker-otel_setup() {
    if [[ "${USE_OTEL}" != "1" ]]; then
        return
    fi

    docker run \
      --network "${NETWORK}" \
      --name "${COLLECTOR}" \
      -v "${BASEDIR}/modules/docker-otel/otel-config.yaml":/etc/otelcol/config.yaml:ro \
      --detach \
      "otel/opentelemetry-collector:${OTEL_VERSION}"

}
