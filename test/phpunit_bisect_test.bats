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

# Run the tests for the phpunit job type (bisect mode)

setup() {
    load 'helpers/common'
    _common_setup
}

teardown() {
    load 'helpers/common'
    _common_teardown
}

@test "PHPUnit bisect tests: run a known 4.4 regression (MDL-81386)" {
    # Set all the required variables.
    JOBTYPE="phpunit"
    PHP_VERSION="8.3"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    PHPUNIT_FILTER="test_enrol_user_sees_own_courses"
    GOOD_COMMIT="b4c6ed36503c0d1e69efdb9b18e6846234706da7"
    BAD_COMMIT="ecddfa6ccd8fa1390cf84a568baee78816b549aa"

    # Checkout
    run git_moodle_checkout v4.3.2
    assert_success

    # Run the job
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: phpunit"
    assert_output --partial "== Moodle branch (version.php): 403"
    assert_output --partial "== PHP version: 8.3"
    assert_output --partial "== DBTYPE: pgsql"
    assert_output --partial "== PHPUNIT_FILTER: test_enrol_user_sees_own_courses"
    assert_output --partial "== DBREPLICAS: 0"
    assert_output --partial "== GOOD_COMMIT: b4c6ed36503c0d1e69efdb9b18e6846234706da7"
    assert_output --partial "== BAD_COMMIT: ecddfa6ccd8fa1390cf84a568baee78816b549aa"
    assert_output --partial "Setting up docker-caches module..."
    assert_output --partial "Bisecting:"
    assert_output --partial "52811000310e7c663fcb75d61b90756f9ded6c7a is the first bad commit"
    assert_output --partial "MDL-67271 core: Add test to find missing SVG icons"
    assert_output --partial "3 files changed, 70 insertions(+), 2 deletions(-)"
    assert_output --partial "Bisect logs and reset:"
    assert_output --partial "Exporting all docker logs for UUID"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "== Exit code: 0"
}

@test "PHPUnit bisect tests: only GOOD_COMMIT specified" {
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

@test "PHPUnit bisect tests: only BAD_COMMIT specified" {
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

@test "PHPUnit bisect tests: same GOOD and BAD commits specified" {
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
