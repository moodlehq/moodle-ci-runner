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

# Run the tests for the postjobs job type

setup() {
    load 'helpers/common'
    _common_setup
}

teardown() {
    load 'helpers/common'
    _common_teardown
}

@test "PostJobs tests: verify the job runs ok" {
    # Set all the required variables toward a run without problems.
    JOBTYPE="postjobs"
    PHP_VERSION="8.1" # Normally the lowest PHP version supported by a branch.
    DBTYPE="mysqli" # The database comparison only works with mysql.
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    GIT_BRANCH="v4.4.1" # Restrict this to just v4.4.1 and v4.4.0 to save time in various jobs.
    GIT_PREVIOUS_COMMIT="v4.4.0"
    betweenversions=20240422
    gitbranchupgraded=MOODLE_402_STABLE,MOODLE_403_STABLE # Two are enough to save time.

    # Checkout codebase
    run git_moodle_checkout $GIT_BRANCH
    assert_success

    # Run the job
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: postjobs"
    assert_output --partial "== Moodle branch (version.php): 404"
    assert_output --partial "== PHP version: 8.1"
    assert_output --partial "== DBTYPE: mysqli"
    assert_output --partial "== DBREPLICAS: 0"
    assert_output --partial "== SCRIPTS: illegal_whitespace detect_conflicts check_upgrade_savepoints"
    assert_output --partial "versions_check_set grunt_process php_lint verify_phpunit_xml compare_databases"
    assert_output --partial "== Git branch (from git): v4.4.1"
    assert_output --partial "Running postjobs job..."
    assert_output --partial "Running script illegal_whitespace"
    assert_output --partial "Exit code of illegal_whitespace: 0"
    assert_output --partial "Running script compare_databases"
    assert_output --partial "The job cannot be skipped"
    assert_output --partial "Ok: Process ended without errors"
    assert_output --partial "Exit code of compare_databases: 0"
    assert_output --partial "Exporting all docker logs for UUID"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "== Exit code: 0"
}

@test "PostJobs tests: verify the job detects problems" {
    # Set all the required variables toward a run without problems.
    JOBTYPE="postjobs"
    PHP_VERSION="8.1" # Normally the lowest PHP version supported by a branch.
    DBTYPE="mysqli" # The database comparison only works with mysql.
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    GIT_BRANCH="v4.4.1" # Restrict this to just v4.4.1 and v4.4.0 to save time in various jobs.
    GIT_PREVIOUS_COMMIT="v4.4.0"
    betweenversions=20251212 # This will fail the versions checker.
    gitbranchupgraded=MOODLE_400_STABLE # This will fail the database comparison (cannot upgrade from 4.0 to 4.4).
    SCRIPTS="php_lint versions_check_set compare_databases" # We only run a few scripts to save time.

    # Checkout codebase
    run git_moodle_checkout $GIT_BRANCH
    assert_success

    # Run the job
    run launch_runner
    assert_failure
    assert_output --partial "== JOBTYPE: postjobs"
    assert_output --partial "== Moodle branch (version.php): 404"
    assert_output --partial "== PHP version: 8.1"
    assert_output --partial "== DBTYPE: mysqli"
    assert_output --partial "== DBREPLICAS: 0"
    assert_output --partial "== SCRIPTS: php_lint versions_check_set compare_databases"
    refute_output --partial "Running script illegal_whitespace"
    assert_output --partial "Running script php_lint"
    assert_output --partial "Exit code of php_lint: 0"
    assert_output --partial "Running script versions_check_set"
    assert_output --partial "== betweenversions: 20251212"
    assert_output --partial "+ ERROR: Version (2024042200) cannot be before 20251212 (YYYYMMDD)"
    assert_output --partial "Exit code of versions_check_set: 1"
    assert_output --partial "Running script compare_databases"
    assert_output --partial "Error: Problem installing Moodle MOODLE_400_STABLE to test upgrade"
    assert_output --partial "Exit code of compare_databases: 1"
    assert_output --partial "Exporting all docker logs for UUID"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "== Exit code: 1"
}
