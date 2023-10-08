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

# Docker healthy module functions.

# This module defines the following env variables.
function docker-healthy_env() {
    env=()
    echo "${env[@]}"
}

# Docker healthy module checks.
function docker-healthy_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the module to work.
    verify_env UUID SHAREDDIR
}

# Docker healthy module setup.
function docker-healthy_setup() {
    echo
    echo ">>> startsection Waiting for all containers to become healthy<<<"
    echo "============================================================================"
    local waitperiod=
    local startingcount=

    for waitperiod in {0..90}; do
        # Note we cannot use the 'health' filter due to https://github.com/moby/moby/issues/35920
        startingcount=$(($(docker ps -a --filter name="${UUID}" | c1grep -e starting -e unhealthy | wc -l)))
        if [[ ${startingcount} -lt 1 ]]; then
            break
        fi
        echo "Waiting ${waitperiod} seconds for ${startingcount} containers to become healthy"
        sleep 1
    done

    startingcount=$(($(docker ps -a --filter name="${UUID}" | c1grep -e starting -e unhealthy | wc -l)))
    if [[ ${startingcount} -gt 0 ]]; then
        print_error "Some containers were too slow. Aborting the run:"
        exit_error "$(docker ps -a --filter name="${UUID}" --filter | c1grep -e starting -e unhealthy)"
    fi
    echo "All containers started OK"

    echo "============================================================================"
    echo ">>> stopsection <<<"
}