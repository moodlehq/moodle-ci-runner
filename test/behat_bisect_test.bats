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

# Run the tests for the behat job type (bisect mode)

setup() {
    load 'helpers/common'
    _common_setup
}

teardown() {
    load 'helpers/common'
    _common_teardown
}

@test "Behat bisect tests: run a known 4.3 regression (MDL-77991)" {
    # Set all the required variables.
    JOBTYPE="behat"
    PHP_VERSION="8.2"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    BEHAT_TAGS="@gradereport_grader&&@core&&~@mod_assign"
    BEHAT_NAME="all the user to expand all of them at once"
    BEHAT_PARALLEL=3
    BEHAT_RERUNS=3
    BEHAT_TIMING_FILENAME="wont_be_used.json"
    GOOD_COMMIT="ce131c354aaebe40340e4f05334164d585087361"
    BAD_COMMIT="567f4c0669e2a37f65d37c2950ccc76cb77a1484"

    # Checkout
    run git_moodle_checkout v4.3.2
    assert_success

    # Run the job
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: behat"
    assert_output --partial "== Moodle branch (version.php): 403"
    assert_output --partial "== PHP version: 8.2"
    assert_output --partial "== DBTYPE: pgsql"
    assert_output --partial "== BEHAT_NAME: all the user to expand all of them at once"
    assert_output --partial "== BEHAT_PARALLEL: 1"
    assert_output --partial "== BEHAT_RERUNS: 0"
    refute_output --partial "wont_be_used.json"
    assert_output --partial "== GOOD_COMMIT: ce131c354aaebe40340e4f05334164d585087361"
    assert_output --partial "== BAD_COMMIT: 567f4c0669e2a37f65d37c2950ccc76cb77a1484"
    assert_output --partial "Setting up docker-selenium module..."
    assert_output --partial "Bisecting:"
    assert_output --partial "1be10f4249868e1bf1e9b44ba71b559c23e0cd06 is the first bad commit"
    assert_output --partial "Merge branch 'MDL-77991' of https://github.com/Chocolate-lightning/moodle"
    assert_output --partial "132 files changed, 3805 insertions(+), 2650 deletions(-)"
    assert_output --partial "Bisect logs and reset:"
    assert_output --partial "Exporting all docker logs for UUID"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "== Exit code: 0"
}

@test "Behat bisect tests: only GOOD_COMMIT specified" {
    # Set all the required variables.
    JOBTYPE="phpunit"
    PHP_VERSION="8.3"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    PHPUNIT_FILTER="test_enrol_user_sees_own_courses"
    GOOD_COMMIT="b4c6ed36503c0d1e69efdb9b18e6846234706da7"

    # Checkout
    run git_moodle_checkout v4.3.2
    assert_success

    # Run the job
    run launch_runner
    assert_failure
    assert_output --partial "ERROR: GOOD_COMMIT is set but BAD_COMMIT is not set."
}

@test "Behat bisect tests: only BAD_COMMIT specified" {
    # Set all the required variables.
    JOBTYPE="phpunit"
    PHP_VERSION="8.3"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    PHPUNIT_FILTER="test_enrol_user_sees_own_courses"
    BAD_COMMIT="b4c6ed36503c0d1e69efdb9b18e6846234706da7"

    # Checkout
    run git_moodle_checkout v4.3.2
    assert_success

    # Run the job
    run launch_runner
    assert_failure
    assert_output --partial "ERROR: BAD_COMMIT is set but GOOD_COMMIT is not set."
}

@test "Behat bisect tests: same GOOD and BAD commits specified" {
    # Set all the required variables.
    JOBTYPE="phpunit"
    PHP_VERSION="8.3"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    GOOD_COMMIT="b4c6ed36503c0d1e69efdb9b18e6846234706da7"
    BAD_COMMIT="${GOOD_COMMIT}"

    # Checkout
    run git_moodle_checkout v4.3.2
    assert_success

    # Run the job
    run launch_runner
    assert_failure
    assert_output --partial "ERROR: GOOD_COMMIT and BAD_COMMIT are set, but they are the same."
}
