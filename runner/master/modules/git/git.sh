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

# Git module functions.

# This module defines the following env variables
function git_env() {
    env=(
        GIT_COMMIT
    )
    echo "${env[@]}"
}

# Git module checks.
function git_check() {
    if ! git --version > /dev/null 2>&1; then
        exit_error "Git is not installed. Please install it and try again."
    fi

    # These env variables must be set for the module to work.
    verify_env CODEDIR
}

# Git module config.
function git_config() {
    # Apply some defaults.
    GIT_COMMIT="N/A"

    # If available, which commit hash is being tested.
    if [[ -d "${CODEDIR}"/.git ]]; then
        GIT_COMMIT=$(cd "${CODEDIR}" && git rev-parse HEAD)
    fi
}
