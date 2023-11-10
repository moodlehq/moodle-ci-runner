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

# Docker Moodle config module.

# This module defines the following env variables.
function moodle-config_env() {
    env=(
        MOODLE_CONFIG
    )
    echo "${env[@]}"
}

# Moodle config module checks.
function moodle-config_check() {
    # Check all module dependencies.
    verify_modules docker env docker-php
}

# Moodle config module init.
function moodle-config_config() {
    # Apply some defaults.
    MOODLE_CONFIG="${MOODLE_CONFIG:-}"
}
