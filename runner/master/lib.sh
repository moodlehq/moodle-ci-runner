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

# Some useful variables to control the orchestration.
# Already checked modules.
__CHECKED_MODULES=()

# Various utility functions used by the CI scripts.

# Verify that all the specified env variables are set.
function verify_env() {
    local error=
    local var=
    for var in "$@"; do
        if [[ ! -v "${var}" ]]; then
            print_error "${var} is not set."
            error=1
        fi
    done

    if [[ -n ${error} ]]; then
        exit 1
    fi
}

# Verify that all the specified utilities are installed and available.
function verify_utilities() {
    local error=
    local util=
    for util in "$@"; do
        if ! command -v "${util}" > /dev/null 2>&1; then
            print_error "${util} is not installed."
            error=1
        fi
    done

    if [[ -n ${error} ]]; then
        exit 1
    fi
}

# Verify that all the specified modules have been already added and checked.
function verify_modules() {
    local error=
    local module=
    for module in "$@"; do
        if ! in_array "${module}" "${__CHECKED_MODULES[@]}"; then
            print_error "${module} module needs to be added before."
            error=1
        fi
    done

    if [[ -n ${error} ]]; then
        exit 1
    fi
}

# Print a error message to stdout.
function print_error() {
    echo "ERROR: $*"
}

# Print a warning message to stdout.
function print_warning() {
    echo "WARNING: $*"
}

# Print message to stdout and exit.
function exit_error() {
    print_error "$@"
    exit 1
}

# "catch-1" grep function, so it doesn't fail the script when there aren't any matches.
function c1grep() {
    grep "$@" || test $? = 1
}

# reverse a string by words.
function string_reverse_by_words() {
    # Using tac, reverse a string by words
    echo "$1" | tac -s ' ' | tr '\n' ' '
}

# verify if a value is in array.
function in_array() {
    local value=$1
    shift
    local item=
    local array=("$@")
    for item in "${array[@]}"; do
        if [[ ${item} == "${value}" ]]; then
            return
        fi
    done
    return 1
}

# Main run function to orchestrate and get the job type done.
# $1 - Job type to run.
function run() {
    local jobtype=${1:-}
    # Verify that the job type has been passed and that it exists.
    if [[ -z ${jobtype} ]]; then
        exit_error "No job type specified."
    fi
    if [[ ! -f "${BASEDIR}/jobtypes/${jobtype}/${jobtype}.sh" ]]; then
        exit_error "Job type ${1} does not exist."
    fi

    # Source the job type.
    # shellcheck source=jobtypes/phpunit.sh # (so we have a reliable job type for other checks)
    source "${BASEDIR}/jobtypes/${jobtype}/${jobtype}.sh"

    # Setup job env variables (modules may need them).
    run_job_env "${jobtype}"

    # Setup all modules env variables and run their checks. One by one.
    run_modules_env_and_check "${jobtype}"

    # Run job checks (after modules env variables have been set).
    run_job_check "${jobtype}"

    # Now it's time to run all the modules config functions (they are optional).
    run_modules_config "${jobtype}"
    run_job_config "${jobtype}"

    # Now it's time to run all the modules setup functions (they are optional).
    run_modules_setup "${jobtype}"

    # Now it's time to run the job setup function (it's optional).
    run_job_setup "${jobtype}"

    # We always run the job with exit on error disabled, so the job can manage the exit codes by itself.
    set +e
    run_job_run "${jobtype}"
    set -e

    # Now it's time to run the job and all the modules teardown functions (they are optional)
    # but we aren't doing that here because it's controlled by traps.
    # Note that they are executed in reverse order, first the job one and, then the
    # modules ones (in the opposite order they were setup). All them are optional.
}

# Get all the environment variables that the job type needs to be exported to env. file
# (the env module uses it to generate the env file).
function get_job_to_env_file() {
    local jobtype=${1:-}
    # Verify that the job type has been passed.
    if [[ -z ${jobtype} ]]; then
        exit_error "No job type specified."
    fi
    # The job type env function is optional, skip if not present.
    if ! type "${jobtype}_to_env_file" > /dev/null 2>&1; then
        return
    fi
    "${jobtype}_to_env_file"
}

# Get all the information that the job wants to add to the summary.
# (the summary module uses it to generate the summary).
function get_job_to_summary() {
    local jobtype=${1:-}
    # Verify that the job type has been passed.
    if [[ -z ${jobtype} ]]; then
        exit_error "No job type specified."
    fi
    # The job type summary function is optional, skip if not present.
    if ! type "${jobtype}_to_summary" > /dev/null 2>&1; then
        return
    fi
    "${jobtype}_to_summary"
}

# Set module variables and run their checks.
#
# Register all job variables (and accumulate them in the __ENV_VARIABLES array)
# and, immediately, run its checks.
function run_job_env() {
    local jobtype=${1:-}
    local exitcode=
    local hasenv=
    # Verify that the job type has been passed.
    if [[ -z ${jobtype} ]]; then
        exit_error "No job type specified."
    fi
    # The job must have an env function.
    if ! type "${jobtype}_env" > /dev/null 2>&1; then
        exit_error "Job ${jobtype} does not have an env function."
    fi
    # Create (as global) and accumulate the env variables.
    for variable in $("${jobtype}_env"); do
        if [[ "${variable}" == "EXITCODE" ]]; then
            exitcode=1
        fi
        declare -g "${variable}=${!variable:-}"
        __ENV_VARIABLES+=("${variable}")
        hasenv=1
    done
    # Ensure that the job always has the EXITCODE env variable.
    if [[ -z ${exitcode} ]]; then
        exit_error "Job ${jobtype} does not have the EXITCODE env variable."
    fi
    # If the job had env variables, it must have a config function.
    if [[ -n ${hasenv} ]] && ! type "${jobtype}_config" > /dev/null 2>&1; then
        exit_error "Job ${jobtype} has env variables and is missing the config function."
    fi
}

# Run job checks.
function run_job_check() {
    local jobtype=${1:-}
    local exitcode=
    # Verify that the job type has been passed.
    if [[ -z ${jobtype} ]]; then
        exit_error "No job type specified."
    fi
    # The job must have a check function.
    if ! type "${jobtype}_check" > /dev/null 2>&1; then
        exit_error "Job ${jobtype} does not have a check function."
    fi
    # Run the job type check.
    echo -n "Checking ${jobtype} job... "
    "${jobtype}_check"
    echo "OK"
}

# Execute the config method for the job type being executed.
function run_job_config() {
    local jobtype=${1:-}
    # Verify that the job type has been passed.
    if [[ -z ${jobtype} ]]; then
        exit_error "No job type specified."
    fi
    # The config function is optional, skip if not present.
    if ! type "${jobtype}_config" > /dev/null 2>&1; then
        return
    fi
    echo "Configuring ${jobtype} job... "
    "${jobtype}_config"
}

# Execute the before_run method for the job type being executed.
function run_job_setup() {
    local jobtype=${1:-}
    # Verify that the job type has been passed.
    if [[ -z ${jobtype} ]]; then
        exit_error "No job type specified."
    fi
    # The setup function is optional, skip if not present.
    if ! type "${jobtype}_setup" > /dev/null 2>&1; then
        return
    fi
    echo "Setting up ${jobtype} job... "
    "${jobtype}_setup"
}

# Execute the run method for the job type being executed.
function run_job_run() {
    local jobtype=${1:-}
    # Verify that the job type has been passed.
    if [[ -z ${jobtype} ]]; then
        exit_error "No job type specified."
    fi
    # The job must have a run function.
    if ! type "${jobtype}_run" > /dev/null 2>&1; then
        exit_error "Job ${jobtype} does not have a run function."
    fi
    echo "Running ${jobtype} job... "
    "${jobtype}_run"
}

# Execute the teardown method for the job type being executed.
function run_job_teardown() {
    local jobtype=${1:-}
    # Verify that the job type has been passed.
    if [[ -z ${jobtype} ]]; then
        exit_error "No job type specified."
    fi
    # The teardown function is optional, skip if not present.
    if ! type "${jobtype}_teardown" > /dev/null 2>&1; then
        return 0 # This is executed by the trap, so we need to specify the exit code to allow it to continue.
    fi
    echo "Finishing ${jobtype} job... "
    "${jobtype}_teardown"
}

# Set module variables and run their checks.
#
# Register all modules variables (and accumulate them in the __ENV_VARIABLES array)
# and, immediately, run their checks.
function run_modules_env_and_check() {
    local module

    for module in $("${jobtype}_modules"); do
        local variable=
        local hasenv=

        # Check if the module exists.
        if [[ ! -f "${BASEDIR}/modules/${module}/${module}.sh" ]]; then
             exit_error "Module ${module} does not exist."
        fi
        # shellcheck source=modules/docker/docker.sh # (so we have a reliable module for other checks)
        source "${BASEDIR}/modules/${module}/${module}.sh"

        # All modules must have an env function.
        if ! type "${module}_env" > /dev/null 2>&1; then
            exit_error "Module ${module} does not have an env function."
        fi
        # Create (as global) and accumulate the env variables.
        for variable in $("${module}_env"); do
            declare -g "${variable}=${!variable:-}"
            __ENV_VARIABLES+=("${variable}")
            hasenv=1
        done

        # If the module had env variables, it must have a config function.
        if [[ -n ${hasenv} ]] && ! type "${module}_config" > /dev/null 2>&1; then
            exit_error "Module ${module} has env variables and is missing the config function."
        fi

        # All modules must have a check function.
        if ! type "${module}_check" > /dev/null 2>&1; then
            exit_error "Module ${module} does not have a check function."
        fi
        # Run the module check.
        echo -n "Checking ${module} module... "
        "${module}_check"
        __CHECKED_MODULES+=("${module}")
        echo "OK"
    done
}

# Execute all the config functions for the modules that the job type needs (they are optional).
function run_modules_config() {
    local module=
    for module in $("${jobtype}_modules"); do
        # Check if the module exists.
        if [[ ! -f "${BASEDIR}/modules/${module}/${module}.sh" ]]; then
             exit_error "Module ${module} does not exist."
        fi
        # shellcheck source=modules/docker/docker.sh # (so we have a reliable module for other checks)
        source "${BASEDIR}/modules/${module}/${module}.sh"
        # The config function is optional, skip if not present.
        if ! type "${module}_config" > /dev/null 2>&1; then
            continue
        fi
        echo "Configuring ${module} module... "
        "${module}_config"
    done
}

# Execute all the setup functions for the modules that the job type needs (they are optional).
function run_modules_setup() {
    local module=
    for module in $("${jobtype}_modules"); do
        # Check if the module exists.
        if [[ ! -f "${BASEDIR}/modules/${module}/${module}.sh" ]]; then
             exit_error "Module ${module} does not exist."
        fi
        # shellcheck source=modules/docker/docker.sh # (so we have a reliable module for other checks)
        source "${BASEDIR}/modules/${module}/${module}.sh"
        # The before_run function is optional, skip if not present.
        if ! type "${module}_setup" > /dev/null 2>&1; then
            continue
        fi
        echo "Setting up ${module} module... "
        "${module}_setup"
    done
}

# Execute all the teardown functions for the modules that the job type needs (they are optional).
function run_modules_teardown() {
    local module=
    local modules=
    local reversed_modules=
    local jobtype=${1:-}
    # Verify that the job type has been passed.
    if [[ -z ${jobtype} ]]; then
        exit_error "No job type specified."
    fi
    # The teardown module functions are executed in reverse order.
    modules=$("${jobtype}_modules")
    reversed_modules="$(string_reverse_by_words "${modules}")"
    for module in ${reversed_modules}; do
        # Check if the module exists.
        if [[ ! -f "${BASEDIR}/modules/${module}/${module}.sh" ]]; then
             exit_error "Module ${module} does not exist."
        fi
        # shellcheck source=modules/docker/docker.sh # (so we have a reliable module for other checks)
        source "${BASEDIR}/modules/${module}/${module}.sh"
        # The teardown function is optional, skip if not present.
        if ! type "${module}_teardown" > /dev/null 2>&1; then
            continue
        fi
        echo "Finishing ${module} module... "
        "${module}_teardown"
    done
}

# To trap any exit gracefully.
function trap_exit() {
    local exitcode=$?
    run_job_teardown "${JOBTYPE}"
    run_modules_teardown "${JOBTYPE}"
    echo
    echo "============================================================================"
    echo "== Exit summary":
    echo "== Job type: ${JOBTYPE}"
    echo "== Date: $(date)"
    echo "== Exit code: ${exitcode}"
    echo "============================================================================"
}

# To trap Crtl-C and exit gracefully.
function trap_ctrl_c() {
  echo
  echo "============================================================================"
  echo "Job was cancelled at user request"
  echo "============================================================================"
  exit 255
}
