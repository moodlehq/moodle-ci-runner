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

# Grunt process script.
#
# This job will run the  moodle-local-ci/grunt_process
# script that will install nodejs, all dependencies and
# execute grunt to verify that everything in built properly (CSS, JS, ...).

# Grunt process script variables to go to the env file.
function postjobs_grunt_process_to_env_file() {
    local env=(
        gitdir
        gitbranch
        npminstall
    )
    echo "${env[@]}"
}

# Grunt process script output to be added to the summary.
function postjobs_grunt_process_to_summary() {
    echo "== gitdir: ${gitdir}"
    echo "== gitbranch: ${gitbranch}"
    echo "== npminstall: ${npminstall}"
}

# Grunt process script config function.
function postjobs_grunt_process_config() {
    # Create all the env variables needed for the script.
    gitdir="/var/www/html"
    gitbranch="${GIT_BRANCH}"
    npminstall="true"
}

# Grunt process script run function.
function postjobs_grunt_process_run() {
    # Run the script (within the container, and it's @ /tmp/local_ci
    # (The script will use WORKSPACE to store the artifacts).
    docker exec -t -u www-data --env WORKSPACE="/shared" "${WEBSERVER}" \
        /tmp/local_ci/grunt_process/grunt_process.sh
}
