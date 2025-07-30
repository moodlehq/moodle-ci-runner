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

# Moodle core (copy) module functions.

# This module defines the following env variables.
function moodle-branch_env() {
    env=(
        MOODLE_BRANCH
    )
    echo "${env[@]}"
}

# Moodle core copy module checks.
function moodle-branch_check() {
    # These env variables must be set for the module to work.
    verify_env CODEDIR
}

# Moodle core copy module config.
function moodle-branch_config() {
    # Get the Moodle branch from code, so we can make decisions based on it.
    if [[ -d "${CODEDIR}/public" ]]; then
        MOODLE_BRANCH=$(grep "\$branch" "${CODEDIR}"/public/version.php | sed "s/';.*//" | sed "s/^\$.*'//")
    else
        MOODLE_BRANCH=$(grep "\$branch" "${CODEDIR}"/version.php | sed "s/';.*//" | sed "s/^\$.*'//")
    fi
}
