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

# Verify that generated phpunit.xml is correct.
#
# This job will run the moodle-local-ci/verify_phpunit_xml
# script to verify that all the information in the generated
# phpunit.xml file is correct (all tests are covered by it and
# other details).

# Verify PHPUnit script variables to go to the env file.
function postjobs_verify_phpunit_xml_to_env_file() {
    local env=(
        phpcmd
        gitdir
        gitbranch
        multipleclassiserror
    )
    echo "${env[@]}"
}

# Verify PHPUnit script output to be added to the summary.
function postjobs_verify_phpunit_xml_to_summary() {
    echo "== phpcmd: ${phpcmd}"
    echo "== gitdir: ${gitdir}"
    echo "== gitbranch: ${gitbranch}"
    echo "== multipleclassiserror: ${multipleclassiserror}"
}

# Verify PHPUnit script config function.
function postjobs_verify_phpunit_xml_config() {
    # Create all the env variables needed for the script.
    phpcmd=php
    gitdir="/var/www/html"
    gitbranch="${GIT_BRANCH}"
    multipleclassiserror="yes"
}

# Verify PHPUnit script run function.
function postjobs_verify_phpunit_xml_run() {
    # Run the script (within the container, and it's @ /tmp/local_ci
    # (The script will use WORKSPACE to store the artifacts).
    # Let's filter out any "^OK: " lines, they aren't important.
    docker exec -t -u www-data --env WORKSPACE="/shared" "${WEBSERVER}" \
        /tmp/local_ci/verify_phpunit_xml/verify_phpunit_xml.sh | grep -v '^OK: '
}
