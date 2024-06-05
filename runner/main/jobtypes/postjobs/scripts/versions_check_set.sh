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

# Verify that all the versions are set correctly.
#
# This job will run the moodle-local-ci/versions_check_set
# script to verify that all the versions are set correctly.

# Versions check script variables to go to the env file.
function postjobs_versions_check_set_to_env_file() {
    local env=(
        phpcmd
        gitdir
        betweenversions
    )
    echo "${env[@]}"
}

# Versions check script output to be added to the summary.
function postjobs_versions_check_set_to_summary() {
    echo "== phpcmd: ${phpcmd}"
    echo "== gitdir: ${gitdir}"
    echo "== betweenversions: ${betweenversions}"
}

# Versions check script config function.
function postjobs_versions_check_set_config() {
    # Create all the env variables needed for the script.
    phpcmd=php
    gitdir="/var/www/html"
    betweenversions=${betweenversions:-}
}

# Versions check script run function.
function postjobs_versions_check_set_run() {
    # Run the script (within the container, and it's @ /tmp/local_ci
    # (The script will use WORKSPACE to store the artifacts).
    docker exec -t -u www-data --env WORKSPACE="/shared" "${WEBSERVER}" \
        /tmp/local_ci/versions_check_set/versions_check_set.sh
}
