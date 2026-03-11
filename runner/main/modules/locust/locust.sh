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
function locust_env() {
    env=(
    )
    echo "${env[@]}"
}

# Moodle composer module checks.
function locust_check() {
    # These env variables must be set for the module to work.
    verify_env CODEDIR

    # We can't verify the WEBSERVER env variable here, as the _check method
    # is executed before the docker-php_setup method that defines it.
}

# Moodle composer module config.
function locust_setup() {
    if [[ "${COMPOSERINSTALL}" != "1" ]]; then
        return
    fi

    git clone https://github.com/andrewnicols/moodle-locust-runner "${WORKSPACE}/moodle-locust-runner"
}
