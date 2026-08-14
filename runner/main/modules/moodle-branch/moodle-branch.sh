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
        MOODLE_HAS_CLASSIC_THEME
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
    local classicthemedir
    if [[ -d "${CODEDIR}/public" ]]; then
        MOODLE_BRANCH=$(grep "\$branch" "${CODEDIR}"/public/version.php | sed "s/';.*//" | sed "s/^\$.*'//")
        classicthemedir="${CODEDIR}/public/theme/classic"
    else
        MOODLE_BRANCH=$(grep "\$branch" "${CODEDIR}"/version.php | sed "s/';.*//" | sed "s/^\$.*'//")
        classicthemedir="${CODEDIR}/theme/classic"
    fi

    # The classic theme is being removed (starting from main), so callers can no
    # longer assume it's there just because of the branch name being tested.
    MOODLE_HAS_CLASSIC_THEME=
    if [[ -f "${classicthemedir}/version.php" ]]; then
        MOODLE_HAS_CLASSIC_THEME="yes"
    fi
}
