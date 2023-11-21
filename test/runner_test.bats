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

# Some basic tests to verify that the runner is working as expected.

setup_file() {
    load 'helpers/common'
    # Install the dummy job type, so we can test various things.
    cp -pr "${RUNNER_DIR}/test/fixtures/jobtypes/dummy" "${RUNNER_DIR}/runner/main/jobtypes/dummy"
}

teardown_file() {
    load 'helpers/common'
    # Remove the dummy job type.
    rm -rf "${RUNNER_DIR}/runner/main/jobtypes/dummy"
}

setup() {
    load 'helpers/common'
    _common_setup
}

teardown() {
    load 'helpers/common'
    _common_teardown
}

@test "Self tests: helper/common.bash sets some env variables" {
    # Verify both the runner dir and the moodle checkout dirs are set and look correct.
    assert [ "${RUNNER_DIR}" != "" ]
    assert [ -f "${RUNNER_DIR}/runner/main/run.sh" ]
    assert [ -d "${MOODLE_CI_RUNNER_GITDIR}" ]
    assert [ -f "${MOODLE_CI_RUNNER_GITDIR}/config-dist.php" ]
    assert [ -f "${MOODLE_CI_RUNNER_GITDIR}/admin/environment.xml" ]

    # Verify that git_moodle_checkout() is working as expected (branch, tag, commit).
    run git_moodle_checkout origin/MOODLE_39_STABLE
    assert_success
    run git_moodle_checkout v3.9.0
    assert_success
    run git_moodle_checkout cafc042bf6
    assert_success
}

@test "Runner tests: All required variables are checked" {
    run git_moodle_checkout origin/MOODLE_39_STABLE

    # No variables set.
    run launch_runner
    assert_failure
    assert_output --partial "ERROR: CODEDIR directory does not exist"

    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"

    # Use invalid JOBTYPE
    JOBTYPE="invalid"
    run launch_runner
    assert_failure
    assert_output --partial "ERROR: Invalid jobtype: invalid"
    assert_output --partial "Exit code: 1"

    # Switch to the dummy jobtype (from fixtures) that will allow us to check more details.
    JOBTYPE="dummy"
    run launch_runner
    assert_success
    assert_output --partial "Checking env module... OK"
    assert_output --partial "Checking docker module... OK"
    assert_output --partial "Checking docker-php module... OK"
    assert_output --partial "Checking dummy job... OK"
    assert_output --partial "Details about the images being used by the run"
    assert_output --partial "moodlehq/moodle-php-apache:"
    assert_output --partial "dummy_setup: Initialising Dummy environment"
    assert_output --partial "dummy_run: Running Dummy environment"
    assert_output --partial "dummy_teardown: Finishing Dummy environment"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "Job type: dummy"
    assert_output --partial "Exit code: 0"

    # Now let's check all the deprecated variables.
    JOBTYPE=
    TESTTORUN="dummy"
    DBSLAVES="test"
    TESTSUITE="test"
    TAGS="test"
    NAME="test"
    BEHAT_TOTAL_RUNS="test"
    BEHAT_NUM_RERUNS="test"
    run launch_runner
    assert_success
    assert_output --partial "TESTTORUN variable is deprecated, use JOBTYPE instead."
    assert_output --partial "DBSLAVES variable is deprecated, use DBREPLICAS instead."
    assert_output --partial "TESTSUITE variable is deprecated, use PHPUNIT_TESTSUITE instead."
    assert_output --partial "TAGS variable is deprecated, use PHPUNIT_FILTER or BEHAT_TAGS instead."
    assert_output --partial "NAME variable is deprecated, use BEHAT_NAME instead."
    assert_output --partial "BEHAT_TOTAL_RUNS variable is deprecated, use BEHAT_PARALLEL instead."
    assert_output --partial "BEHAT_NUM_RERUNS variable is deprecated, use BEHAT_RERUNS instead."
}
