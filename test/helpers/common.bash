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

# Some common stuff and functions to be used by the tests.

if [[ -z ${MOODLE_CI_RUNNER_GITDIR} ]]; then
    echo "Please, set the MOODLE_CI_RUNNER_GITDIR environment variable to the path of a moodle.git checkout."
    echo "WARNING: The tests will cause destructive changes to the checkout, so use a separate one."
    exit 1
fi

MOODLE_CI_RUNNER_GITDIR=$(realpath "${MOODLE_CI_RUNNER_GITDIR}")

if [[ ! -d "${MOODLE_CI_RUNNER_GITDIR}" ]]; then
    echo "The MOODLE_CI_RUNNER_GITDIR environment variable is not set to a valid path."
    exit 1
fi

# Base path of moodle-ci-runner.
RUNNER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." >/dev/null 2>&1 && pwd )"

function git_moodle_checkout() {
    # Checkout a branch, tag or commit in the moodle.git repository.
    # $1: Branch, tag or commit to checkout.
    local branch="$1"

    if [[ -z ${branch} ]]; then
        echo "Please, specify a branch, tag or commit to checkout."
        exit 1
    fi

    if [[ ! -d "${MOODLE_CI_RUNNER_GITDIR}" ]]; then
        echo "The MOODLE_CI_RUNNER_GITDIR environment variable is not set to a valid path."
        exit 1
    fi

    # Checkout the branch or tag.
    git -C "${MOODLE_CI_RUNNER_GITDIR}" --git-dir .git checkout -f --quiet "${branch}" || exit 1
}

function launch_runner() {
    # Launch the runner with the given arguments.
    source "${RUNNER_DIR}"/runner/main/run.sh
}

function _common_setup() {
    # Load bats-support and bats-assert helpers.
    load 'helpers/bats-support/load'
    load 'helpers/bats-assert/load'
}

function _common_teardown() {
    # Restore the moodle.git repository to the main branch.
    git -C "${MOODLE_CI_RUNNER_GITDIR}" --git-dir .git checkout -f --quiet "main" || exit 1
}
