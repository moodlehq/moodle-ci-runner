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

# Dummy job for testing purposes (originally copied from the Dummy job).

# Dummy needed variables to go to the env file.
function dummy_to_env_file() {
    local env=(
    )
    echo "${env[@]}"
}

# This job type defines the following env variables
function dummy_env() {
    env=(
        EXITCODE
    )
    echo "${env[@]}"
}

# Dummy needed modules. Note that the order is important.
function dummy_modules() {
    local modules=(
        env
        docker
        docker-php
        docker-summary
    )
    echo "${modules[@]}"
}

# Dummy job type checks.
function dummy_check() {
    # Check all module dependencies.
    verify_modules $(dummy_modules)

    # These env variables must be set for the job to work.
    verify_env UUID ENVIROPATH WEBSERVER
}

# Dummy job type init.
function dummy_config() {
    # Apply some defaults.
    EXITCODE=0
}

# Dummy job type setup.
function dummy_setup() {
    echo " dummy_setup: Initialising Dummy environment"
}

# Dummy job type run.
function dummy_run() {
    echo " dummy_run: Running Dummy environment"
}

# Dummy job type teardown.
function dummy_teardown() {
    echo " dummy_teardown: Finishing Dummy environment"
}