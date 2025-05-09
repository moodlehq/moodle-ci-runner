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

# Run the tests for the phpunit job type
# Note that, to save time, we only run the tests for some testsuite or filter.

setup() {
    load 'helpers/common'
    _common_setup
}

teardown() {
    load 'helpers/common'
    _common_teardown
}

@test "PHPUnit tests: run the job for v3.9.0 and 1 test suite" {
    # Set all the required variables.
    JOBTYPE="phpunit"
    PHP_VERSION="7.4"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    PHPUNIT_TESTSUITE="mod_label_testsuite"

    # Checkout v3.9.0
    run git_moodle_checkout v3.9.0
    assert_success

    # Run the job
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: phpunit"
    assert_output --partial "== Moodle branch (version.php): 39"
    assert_output --partial "== PHP version: 7.4"
    assert_output --partial "== DBTYPE: pgsql"
    assert_output --partial "== PHPUNIT_TESTSUITE: mod_label_testsuite"
    assert_output --partial "== DBREPLICAS: 0"
    assert_output --partial "Setting up docker-caches module..."
    assert_output --partial "Initialising Moodle PHPUnit test environment..."
    assert_output --partial "Running: php vendor/bin/phpunit"
    assert_output --partial "OK (8 tests, 32 assertions)"
    assert_output --partial "Exporting all docker logs for UUID"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "== Exit code: 0"
}

@test "PHPUnit tests: run the job for main with filter applied" {
    # Set all the required variables.
    JOBTYPE="phpunit"
    DBTYPE="mysqli"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    PHPUNIT_FILTER="label"
    MOODLE_CONFIG='{"test": "test"}'

    # Checkout main
    run git_moodle_checkout main
    assert_success

    # Run the job
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: phpunit"
    assert_output --partial "== PHP version: 8.2"
    assert_output --partial "== DBTYPE: mysqli"
    assert_output --partial "== PHPUNIT_FILTER: label"
    assert_output --partial "== DBREPLICAS: 0"
    assert_output --partial "== MOODLE_CONFIG: {\"test\": \"test\"}"
    assert_output --partial "PHPUnit test environment setup complete"
    assert_output --partial "Running: php vendor/bin/phpunit"
    assert_output --partial "== Exit code: 0"
}

@test "PHPUnit tests: run the job for MDL-83424 with filter applied" {
    # Set all the required variables.
    JOBTYPE="phpunit"
    PHP_VERSION="8.4"
    DBTYPE="pgsql"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    PHPUNIT_TESTSUITE="mod_label_testsuite"

    # Checkout main
    run git_moodle_checkout MDL-83424-main https://github.com/andrewnicols/moodle.git
    assert_success

    # Run the job
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: phpunit"
    assert_output --partial "== Moodle branch (version.php): 501"
    assert_output --partial "== PHP version: 8.4"
    assert_output --partial "== DBTYPE: pgsql"
    assert_output --partial "== PHPUNIT_TESTSUITE: mod_label_testsuite"
    assert_output --partial "== DBREPLICAS: 0"
    assert_output --partial "Setting up docker-caches module..."
    assert_output --partial "Initialising Moodle PHPUnit test environment..."
    assert_output --partial "Running: php vendor/bin/phpunit"
    assert_output --partial "OK"
    assert_output --regexp "Tests: [0-9]+"
    assert_output --partial "Exporting all docker logs for UUID"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "== Exit code: 0"
}
