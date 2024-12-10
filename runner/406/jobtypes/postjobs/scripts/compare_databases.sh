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

# Compare databases script.
#
# This job will run the moodle-local-ci/comapre_databases
# script that compares the DB schema of installed and
# upgraded databases to verify they are always 100% the same.

# Compare databases script variables to go to the env file.
function postjobs_compare_databases_to_env_file() {
    local env=(
        gitdir
        gitbranchinstalled
        gitbranchupgraded

        GIT_PREVIOUS_COMMIT
        GIT_COMMIT

        gitcmd
        phpcmd
        mysqlcmd

        dblibrary
        dbtype
        dbhost1
        dbuser1
        dbpass1
    )
    echo "${env[@]}"
}

# Compare databases script output to be added to the summary.
function postjobs_compare_databases_to_summary() {
    echo "== gitdir: ${gitdir}"
    echo "== gitbranchinstalled: ${gitbranchinstalled}"
    echo "== gitbranchupgraded: ${gitbranchupgraded}"
    echo "== GIT_PREVIOUS_COMMIT: ${GIT_PREVIOUS_COMMIT}"
    echo "== GIT_COMMIT: ${GIT_COMMIT}"
    echo "== gitcmd: ${gitcmd}"
    echo "== phpcmd: ${phpcmd}"
    echo "== mysqlcmd: ${mysqlcmd}"
    echo "== dblibrary: ${dblibrary}"
    echo "== dbtype: ${dbtype}"
    echo "== dbhost1: ${dbhost1}"
    echo "== dbuser1: ${dbuser1}"
    echo "== dbpass1: ${dbpass1}"
}

# Compare databases script config function.
function postjobs_compare_databases_config() {
    # Create all the env variables needed for the script.
    gitdir="/var/www/html"
    gitbranchinstalled="${GIT_BRANCH}"
    gitbranchupgraded="${gitbranchupgraded:-}"
    GIT_PREVIOUS_COMMIT=${GIT_PREVIOUS_COMMIT:-}
    GIT_COMMIT=${GIT_COMMIT:-}
    gitcmd="git"
    phpcmd="php"
    mysqlcmd="mysql"
    dblibrary="native"
    dbtype="${DBTYPE}"
    dbhost1="${DBHOST}"
    dbuser1="root" # The script is going to create databases, so it needs root user access.
    dbpass1="${DBPASS}"

    # Error if the dbtype is not supported (only mysqli is supported).
    if [[ "${dbtype}" != "mysqli" ]]; then
        exit_error "Only mysqli is supported for the compare databases script."
    fi

}

# Compare databases run function.
function postjobs_compare_databases_run() {
    # Run the script (within the container, and it's @ /tmp/local_ci
    # (The script will use WORKSPACE to store the artifacts).

    # First, check if any change (db install/upgrade, versions bump...) has happened.
    # in order to decide if the comparison is needed.
    if ! docker exec -t -u www-data --env WORKSPACE="/shared" "${WEBSERVER}" \
            /tmp/local_ci/compare_databases/run_conditionally.sh; then
        return # We can skip the comparison, nothing relevant has changed.
    fi

    # Run the script (within the container, and it's @ /tmp/local_ci
    # (The script will use WORKSPACE to store the artifacts).
    docker exec -t -u www-data --env WORKSPACE="/shared" "${WEBSERVER}" \
        /tmp/local_ci/compare_databases/compare_databases.sh
}
