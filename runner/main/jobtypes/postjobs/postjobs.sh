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

# Post-jobs job type functions.
#
# This job type is used to run all the post-checks that we use to verify various aspects
# after any new code arrives to the Moodle repository (normally during integration).

# Post-jobs needed variables to go to the env file.
function postjobs_to_env_file() {
    local env=(
        DBTYPE
        DBTAG
        DBHOST
        DBNAME
        DBUSER
        DBPASS
        DBCOLLATION
        DBREPLICAS
        DBHOST_DBREPLICA

        MOODLE_CONFIG
    )

    # We also need to add all the env variables required by the post-jobs scripts.
    for script in "${SCRIPTS[@]}"; do
        # Add the script env variables to the list.
        env+=($("postjobs_${script}_to_env_file"))
    done
    echo "${env[@]}"
}

# Post-jobs information to be added to the summary.
function postjobs_to_summary() {
    echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
    echo "== PHP version: ${PHP_VERSION}"
    echo "== DBTYPE: ${DBTYPE}"
    echo "== DBTAG: ${DBTAG}"
    echo "== DBCOLLATION: ${DBCOLLATION}"
    echo "== DBREPLICAS: ${DBREPLICAS}"
    echo "== SCRIPTS: ${SCRIPTS[*]}"
    echo "== Git branch (from git): ${GIT_BRANCH}"
    echo "== Local CI path: ${LOCAL_CI_PATH}"
    echo "== MOODLE_CONFIG: ${MOODLE_CONFIG}"
}

# This job type defines the following env variables
function postjobs_env() {
    env=(
        SCRIPTS
        GIT_BRANCH
        EXITCODE
    )
    echo "${env[@]}"
}

# Post-jobs needed modules. Note that the order is important.
function postjobs_modules() {
    local modules=(
        env
        summary
        moodle-branch
        docker
        docker-logs
        git
        plugins
        docker-database
        docker-php
        moodle-config
        moodle-core-copy
        docker-healthy
        docker-summary
    )
    echo "${modules[@]}"
}

# Post-jobs job type checks.
function postjobs_check() {
    # Check all module dependencies.
    verify_modules $(postjobs_modules)

    # These env variables must be set for the job to work.
    verify_env UUID ENVIROPATH WEBSERVER SHAREDDIR LOCAL_CI_PATH

    # Verify that moodle-local_ci is set, because we require it.
    # (note that the moodle-core-copy module perform further checks)
    if [[ -z "${LOCAL_CI_PATH}" ]]; then
        exit_error "LOCAL_CI_PATH must be defined and point to a valid moodle-local_ci checkout"
    fi
}

# Post-jobs job type init.
function postjobs_config() {
    # Apply some defaults.
    EXITCODE=0

    # Various scripts executed by this job do require full access to git, to
    # be able to compare branches, switch branches, ...
    FULLGIT="yes"

    # Add here all the scripts that will be executed by this job, if not specified in the env.
    if [[ -z "${SCRIPTS}" ]]; then
        SCRIPTS=(
            "illegal_whitespace"
            "detect_conflicts"
            "check_upgrade_savepoints"
            "versions_check_set"
            "grunt_process"
            "php_lint"
            "verify_phpunit_xml"
            "compare_databases"
        )
    else
        # Ensure that the scripts is an array (from comma or space separated string).
        IFS=', ' read -r -a SCRIPTS <<< "${SCRIPTS}"
    fi

    # Get the current git branch (really, it's a reference, can be branch, tag, commit, ...).
    # Only if it's not set already.
    GIT_BRANCH=${GIT_BRANCH:-$(git -C "${CODEDIR}" rev-parse --abbrev-ref HEAD)}

    # We have to load all the configured scripts and perform various validations.
    for script in "${SCRIPTS[@]}"; do
        # Check if the script exists.
        if [[ ! -f "${BASEDIR}/jobtypes/postjobs/scripts/${script}.sh" ]]; then
            echo "${BASEDIR}/jobtypes/postjobs/scripts/${script}.sh"
             exit_error "Script ${script} does not exist."
        fi
        # shellcheck source=jobtypes/postjobs/scripts/illegal_whitespace/illegal_whitespace.sh
        source "${BASEDIR}/jobtypes/postjobs/scripts/${script}.sh"
        # All scripts must have the following functions:
        # - ${script}_to_env_file(): To add information to the env file.
        if ! type "postjobs_${script}_to_env_file" > /dev/null 2>&1; then
            exit_error "Post job script ${script} does not have a postjobs_${script}_to_env file function."
        fi
        # - ${script}_to_summary(): To add information to the summary.
        if ! type "postjobs_${script}_to_summary" > /dev/null 2>&1; then
            exit_error "Post job script ${script} does not have a postjobs_${script}_to_summary function."
        fi
        # - ${script}_config(): To prepare the environment.
        if ! type "postjobs_${script}_config" > /dev/null 2>&1; then
            exit_error "Post job script ${script} does not have a postjobs_${script}_config function."
        fi
        # - ${script}_run(): To effectively execute the script.
        if ! type "postjobs_${script}_run" > /dev/null 2>&1; then
            exit_error "Post job script ${script} does not have a postjobs_${script}_run function."
        fi

        # Arrive here, we can proceed to run the script config function.
        echo "Configuring ${script} script..."
        "postjobs_${script}_config"
    done
}

# Post-jobs job type setup.
function postjobs_setup() {
    # Not much to do here, the scripts don't require any setup, just configuration,
    # and that has been already provided by the postjobs_config function.
    true
}

# Post-jobs job type run.
function postjobs_run() {
    # We are going to run all the configured scripts.
    for script in "${SCRIPTS[@]}"; do
    # Run the command
        echo ">>> startsection Running script ${script} at $(date) <<<"
        echo "============================================================================"
        echo "Using configuration:"
        "postjobs_${script}_to_summary"
        echo "Running ${script} script..."
        "postjobs_${script}_run"
        local exit_code=$?
        echo "Exit code of ${script}: ${exit_code}"
        echo "============================================================================"
        echo ">>> stopsection <<<"
        if [[ exit_code -ne 0 ]]; then
            echo "^^^ SCRIPT ERROR: Execution of ${script} script failed with exit code ${exit_code} ^^^"
            EXITCODE=1
        fi
    done

}
