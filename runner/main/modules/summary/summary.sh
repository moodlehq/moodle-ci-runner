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

# Summary module functions.

# This module defines the following env variables
function summary_env() {
    env=()
    echo "${env[@]}"
}

# Summary module checks.
function summary_check() {
    # In order to print this as soon as possible, we aren't going to check
    # for dependencies here, but will do it in the summary_setup() function.
    # (once all the modules have already defined their env variables).
    # Note that this is highly exceptional and should not be done in other modules.
    true
}

# Summary module setup.
function summary_setup() {
    # We are checking for dependencies here exceptionally. See summary_check() above for more info.
    # Check all module dependencies.
    verify_modules env docker-php moodle-core-copy

    # These env variables must be set for the database module to work.
    verify_env JOBTYPE BUILD_ID WORKSPACE CODEDIR SHAREDDIR UUID GIT_COMMIT ENVIROPATH

    # Print a summary of the job.
    # Note that this only includes the variables that are common for all the job types.
    # Each job is responsible (_to_summary() function) to complete the list with its own variables
    # or anything else that it wants to add to the summary.
    echo "============================================================================"
    echo "= Job summary <<<"
    echo "============================================================================"
    echo "== JOBTYPE: ${JOBTYPE}"
    echo "== Build Id: ${BUILD_ID}"
    echo "== Workspace: ${WORKSPACE}"
    echo "== Code directory: ${CODEDIR}"
    echo "== Shared directory: ${SHAREDDIR}"
    echo "== UUID / Container suffix: ${UUID}"
    echo "== Environment: ${ENVIROPATH}"
    echo "== GIT commit: ${GIT_COMMIT}"

    # Add all the summary information that the job type wants to add.
    get_job_to_summary "${JOBTYPE}"
    echo "============================================================================"
}