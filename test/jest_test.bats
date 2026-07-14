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

# Run the tests for the jest job type.

setup() {
    load 'helpers/common'
    _common_setup
}

teardown() {
    load 'helpers/common'
    _common_teardown
}

@test "Jest tests: run the job for main" {
    # Set all the required variables.
    JOBTYPE="jest"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"

    # Checkout main
    run git_moodle_checkout main
    assert_success

    # Run the job
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: jest"
    assert_output --partial "== Moodle branch (version.php):"
    assert_output --partial "== Node version: 22"
    assert_output --partial "== JEST_FILTER:"
    assert_output --partial "Initialising Jest environment"
    assert_output --partial "Running: npm test"
    assert_output --partial "Test Suites:"
    assert_output --partial "Exporting all docker logs for UUID"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "== Exit code: 0"
}

@test "Jest tests: run the job for main with filter applied" {
    # Set all the required variables.
    JOBTYPE="jest"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    JEST_FILTER="pendingstrings"

    # Checkout main
    run git_moodle_checkout main
    assert_success

    # Run the job
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: jest"
    assert_output --partial "== Node version: 22"
    assert_output --partial "== JEST_FILTER: pendingstrings"
    assert_output --partial "Initialising Jest environment"
    assert_output --partial "Running: npm test -- --passWithNoTests pendingstrings"
    assert_output --partial "No tests found"
    assert_output --partial "== Exit code: 0"
}
