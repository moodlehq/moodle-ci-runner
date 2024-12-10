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

# Docker sumary module functions.

# This module defines the following env variables.
function docker-summary_env() {
    env=()
    echo "${env[@]}"
}

# Docker summary module checks.
function docker-summary_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the module to work.
    verify_env UUID SHAREDDIR
}

# Docker summary module setup.
function docker-summary_setup() {
    # Prepare the summary of images being used by the run (creation date & digest)
    echo
    echo ">>> startsection Details about the images being used by the run<<<"
    echo "============================================================================"
    docker ps --filter "name=${UUID}" --format='{{.Image}}' | sort | uniq | xargs -I{} \
        docker image inspect \
            --format '{} {{if .Created}}created:{{.Created}}{{end}} {{if .RepoDigests}}{{index .RepoDigests 0}}{{end}}' {} | \
        tr '@' ' ' | cut -f1,2,4 -d' '

    echo "============================================================================"
    echo ">>> stopsection <<<"
}