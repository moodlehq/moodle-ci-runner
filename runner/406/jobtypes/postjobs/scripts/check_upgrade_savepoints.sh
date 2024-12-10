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

# Check upgrade savepoints script.
#
# This job will run the moodle-local-ci/check_upgrade_savepoints
# script to verify that all the upgrade save points / steps make sense.

# Check upgrade savepoints script variables to go to the env file.
function postjobs_check_upgrade_savepoints_to_env_file() {
    local env=(
        gitdir
        gitbranch
    )
    echo "${env[@]}"
}

# Check upgrade savepoints script output to be added to the summary.
function postjobs_check_upgrade_savepoints_to_summary() {
    echo "== gitdir: ${gitdir}"
    echo "== gitbranch: ${gitbranch}"
}

# Check upgrade savepoints script config function.
function postjobs_check_upgrade_savepoints_config() {
    # Create all the env variables needed for the script.
    gitdir="/var/www/html"
    gitbranch="${GIT_BRANCH}"
}

# Check upgrade savepoints script run function.
function postjobs_check_upgrade_savepoints_run() {
    # Run the script (within the container, and it's @ /tmp/local_ci
    # (The script will use WORKSPACE to store the artifacts).
    docker exec -t -u www-data --env WORKSPACE="/shared" "${WEBSERVER}" \
        /tmp/local_ci/check_upgrade_savepoints/check_upgrade_savepoints.sh
}
