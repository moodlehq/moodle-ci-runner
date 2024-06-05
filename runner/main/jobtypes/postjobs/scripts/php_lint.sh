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

# PHP lint codebase (full or only modified).
#
# This job will run the PHP linter against codebase. When information
# about the previous commit is available, it will only lint the files
# modified since then. Else, all the codebase will be linted.

# PHP lint script variables to go to the env file.
function postjobs_php_lint_to_env_file() {
    local env=(
        gitcmd
        phpcmd
        gitdir
        GIT_PREVIOUS_COMMIT
        GIT_COMMIT
    )
    echo "${env[@]}"
}

# PHP lint script output to be added to the summary.
function postjobs_php_lint_to_summary() {
    echo "== gitcmd: ${gitcmd}"
    echo "== phpcmd: ${phpcmd}"
    echo "== gitdir: ${gitdir}"
    echo "== GIT_PREVIOUS_COMMIT: ${GIT_PREVIOUS_COMMIT}"
    echo "== GIT_COMMIT: ${GIT_COMMIT}"
}

# PHP lint script config function.
function postjobs_php_lint_config() {
    # Create all the env variables needed for the script.
    gitcmd="git"
    phpcmd="php"
    gitdir="/var/www/html"
    GIT_PREVIOUS_COMMIT=${GIT_PREVIOUS_COMMIT:-}
    GIT_COMMIT=${GIT_COMMIT:-}
}

# PHP lint script run function.
function postjobs_php_lint_run() {
    # Run the script (within the container, and it's @ /tmp/local_ci
    # (The script will use WORKSPACE to store the artifacts).
    # Let's filter out any " - OK" lines, they aren't important.
    docker exec -t -u www-data --env WORKSPACE="/shared" "${WEBSERVER}" \
        /tmp/local_ci/php_lint/php_lint.sh | grep -v ' - OK'
}
