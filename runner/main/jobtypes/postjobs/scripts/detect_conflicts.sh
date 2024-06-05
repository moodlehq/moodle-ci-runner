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

# Detect conflicts script.
#
# This job will run the moodle-local-ci/detect_conflicts
# script to check for any conflict left in the code.

# Detect conflicts script variables to go to the env file.
function postjobs_detect_conflicts_to_env_file() {
    local env=(
        gitdir
        gitbranch
    )
    echo "${env[@]}"
}

# Detect conflicts script output to be added to the summary.
function postjobs_detect_conflicts_to_summary() {
    echo "== gitdir: ${gitdir}"
    echo "== gitbranch: ${gitbranch}"
}

# Detect conflicts script config function.
function postjobs_detect_conflicts_config() {
    # Create all the env variables needed for the script.
    gitdir="/var/www/html"
    gitbranch="${GIT_BRANCH}"
}

# Detect conflicts run function.
function postjobs_detect_conflicts_run() {
    # Run the script (within the container, and it's @ /tmp/local_ci
    # (The script will use WORKSPACE to store the artifacts).
    docker exec -t -u www-data --env WORKSPACE="/shared" "${WEBSERVER}" \
        /tmp/local_ci/detect_conflicts/detect_conflicts.sh
}
