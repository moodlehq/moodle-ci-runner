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

set -u
set -e
set -o pipefail

# Let's define some variables that will be used by the scripts.

# Base directory where the scripts are located.
BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Include the functions.
source "${BASEDIR}/lib.sh"

# Trap to finish the execution (exit and Ctrl+C).
trap trap_exit EXIT
trap trap_ctrl_c INT

# Verify that all the needed utilities are installed and available.
verify_utilities awk grep head mktemp pwd sed sha1sum sort tac tr true uniq uuid xargs

# Check we are using bash 4.3 or higher.
if [[ ${BASH_VERSINFO[0]} -lt 4 ]] || [[ ${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -lt 3 ]]; then
    exit_error "Bash 4.3 or higher is required."
fi

# Base directory to be used as workspace for the execution.
if [[ -z ${WORKSPACE:-} ]]; then
    # If not defined, create one.
    MKTEMP=$(mktemp -d)
    WORKSPACE="${MKTEMP}/workspace"
fi

# Base directory where the code is located.
CODEDIR="${CODEDIR:-${WORKSPACE}/moodle}"

# Fail if CODEDIR does not exist.
if [[ ! -d ${CODEDIR} ]]; then
    exit_error "CODEDIR directory does not exist: ${CODEDIR}"
fi

# BUILD_ID, if not defined use the current PID.
BUILD_ID="${BUILD_ID:-$$}"

# TODO: Remove this once https://github.com/moodlehq/moodle-local_ci/issues/303 is fixed.
# Always make BUILD_NUMBER available, some old scripts use it.
BUILD_NUMBER="${BUILD_ID}"

# Base directory to be shared with some containers that will read/write information there (timing, environment, logs... etc.).
SHAREDDIR="${WORKSPACE}"/"${BUILD_ID}"

# Ensure that the output directory exists.
# It must also be set with the sticky bit, and world writable.
mkdir -p "${SHAREDDIR}"
chmod -R g+sw,a+sw "${SHAREDDIR}"

# UUID to be used as suffix for the containers and other stuff.
UUID=$(uuid | sha1sum | awk '{print $1}' | head -c 16)

# Job type to run (from "jobtypes" directory).
# BC compatibility with old phpunit and behat variable names.
# TODO: Remove this once all the uses in CI are updated to use the new ones.
JOBTYPE="${JOBTYPE:-${TESTTORUN:-phpunit}}"
if [[ -n ${TESTTORUN:-} ]]; then
    print_warning "TESTTORUN variable is deprecated, use JOBTYPE instead."
fi

# Ensure that the job type is valid.
if [[ ! -f ${BASEDIR}"/jobtypes/"${JOBTYPE}/${JOBTYPE}.sh ]]; then
  exit_error "Invalid jobtype: ${JOBTYPE}"
fi

# Some jobs may need to have a working, complete git repository,
# standalone (without references) and with access to all branches
# and commits. This variable can be used to define such behaviour
# from the jobs (or the caller).
FULLGIT="${FULLGIT:-}"

# Caches directories, used for composer, to accelerate git operations...
CACHEDIR="${CACHEDIR:-${HOME}/caches}"
COMPOSERCACHE="${COMPOSERCACHE:-${CACHEDIR}/composer}"

# BC compatibility with old replica names.
# TODO: Remove this once all the uses in CI are updated to use the new ones.
DBREPLICAS="${DBREPLICAS:-${DBSLAVES:-}}"
if [[ -n ${DBSLAVES:-} ]]; then
    print_warning "DBSLAVES variable is deprecated, use DBREPLICAS instead."
fi

# BC compatibility with old phpunit and behat variable names.
# TODO: Remove this once all the uses in CI are updated to use the new ones.
# PHPUnit:
PHPUNIT_TESTSUITE="${PHPUNIT_TESTSUITE:-${TESTSUITE:-}}"
PHPUNIT_FILTER="${PHPUNIT_FILTER:-${TAGS:-}}"
# Behat:
BEHAT_TAGS="${BEHAT_TAGS:-${TAGS:-}}"
BEHAT_NAME="${BEHAT_NAME:-${NAME:-}}"
BEHAT_PARALLEL="${BEHAT_PARALLEL:-${BEHAT_TOTAL_RUNS:-3}}"
BEHAT_RERUNS="${BEHAT_RERUNS:-${BEHAT_NUM_RERUNS:-1}}"
# Print a warning if the old variables are used.
if [[ -n ${TESTSUITE:-} ]]; then
    print_warning "TESTSUITE variable is deprecated, use PHPUNIT_TESTSUITE instead."
fi
if [[ -n ${TAGS:-} ]]; then
    print_warning "TAGS variable is deprecated, use PHPUNIT_FILTER or BEHAT_TAGS instead."
fi
if [[ -n ${NAME:-} ]]; then
    print_warning "NAME variable is deprecated, use BEHAT_NAME instead."
fi
if [[ -n ${BEHAT_TOTAL_RUNS:-} ]]; then
    print_warning "BEHAT_TOTAL_RUNS variable is deprecated, use BEHAT_PARALLEL instead."
fi
if [[ -n ${BEHAT_NUM_RERUNS:-} ]]; then
    print_warning "BEHAT_NUM_RERUNS variable is deprecated, use BEHAT_RERUNS instead."
fi

# Everything is ready, let's run the job.
run "${JOBTYPE}"

# All done, exit with the exit code of the job.
exit "${EXITCODE}"

# Done! ============ Empty below this line ============
