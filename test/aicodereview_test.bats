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

# Run the tests for the aicodereview job type.
# These tests use DRY_RUN mode to avoid requiring an AI API key.

setup() {
    load 'helpers/common'
    _common_setup
}

teardown() {
    load 'helpers/common'
    _common_teardown
}

@test "AI Code Review: fails without AI_API_KEY when not in DRY_RUN mode" {
    # Set required variables but omit AI_API_KEY.
    JOBTYPE="aicodereview"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"

    # Checkout main.
    run git_moodle_checkout main
    assert_success

    # Run the job — should fail because AI_API_KEY is not set.
    run launch_runner
    assert_failure
    assert_output --partial "AI_API_KEY is not set"
}

@test "AI Code Review: dry run succeeds with main checkout" {
    # Set all required variables in DRY_RUN mode (no AI key needed).
    JOBTYPE="aicodereview"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    DRY_RUN="1"
    AI_MODEL="dry-run-test"
    REVIEW_TARGET_BRANCH="origin/main"

    # Checkout main.
    run git_moodle_checkout main
    assert_success

    # Run the job.
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: aicodereview"
    assert_output --partial "== AI_MODEL: dry-run-test"
    assert_output --partial "== DRY_RUN: 1"
    assert_output --partial "== REVIEW_TARGET_BRANCH: origin/main"
    assert_output --partial "DRY_RUN mode: Skipping AI API calls"
    assert_output --partial "Dry Run"
    assert_output --partial "== Exit code: 0"
}

@test "AI Code Review: dry run shows diff statistics" {
    # Set all required variables.
    JOBTYPE="aicodereview"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    DRY_RUN="1"
    AI_MODEL="dry-run-test"

    # Checkout main.
    run git_moodle_checkout main
    assert_success

    # Run the job.
    run launch_runner
    assert_success
    assert_output --partial "Extracting git diff"
    assert_output --partial "Diff size:"
    assert_output --partial "Files changed:"
    assert_output --partial "Stopping and removing all docker containers"
}

@test "AI Code Review: summary includes all expected fields" {
    # Set all required variables.
    JOBTYPE="aicodereview"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    DRY_RUN="1"
    AI_MODEL="test-model"
    JIRA_ISSUE="MDL-99999"
    REVIEW_MAX_ITERATIONS="5"

    # Checkout main.
    run git_moodle_checkout main
    assert_success

    # Run the job.
    run launch_runner
    assert_success
    assert_output --partial "== AI_MODEL: test-model"
    assert_output --partial "== JIRA_ISSUE: MDL-99999"
    assert_output --partial "== REVIEW_MAX_ITERATIONS: 5"
    assert_output --partial "== DBTYPE: pgsql"
}

