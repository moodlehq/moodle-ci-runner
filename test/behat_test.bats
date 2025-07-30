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

# Run the tests for the behat job type
# Note that, to save time, we only run the tests for some tag or name.

setup() {
    load 'helpers/common'
    _common_setup
}

teardown() {
    load 'helpers/common'
    _common_teardown
}

@test "Behat tests: run the job for v3.9.0 and some tags" {
    # Set all the required variables.
    JOBTYPE="behat"
    PHP_VERSION="7.4"
    DBTYPE="mariadb"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    BEHAT_TAGS="@mod_label&&@core,~@mod_assign"
    BEHAT_PARALLEL="1"
    BROWSER_HEADLESS="1"

    # Checkout v3.9.0 (note this is known to fail for @mod_label
    run git_moodle_checkout v3.9.0
    assert_success

    # Run the job
    run launch_runner
    assert_failure
    assert_output --partial "== JOBTYPE: behat"
    assert_output --partial "== Moodle branch (version.php): 39"
    assert_output --partial "== PHP version: 7.4"
    assert_output --partial "== DBTYPE: mariadb"
    assert_output --partial "== BEHAT_TAGS: @mod_label"
    assert_output --partial "== DBREPLICAS: 0"
    assert_output --partial "== BEHAT_PARALLEL: 1"
    assert_output --partial "== DBCOLLATION: utf8mb4_bin"
    assert_output --partial "Setting up docker-selenium module..."
    assert_output --partial "Initialising Behat environment"
    assert_output --partial "Running: php admin/tool/behat/cli/init.php"
    assert_output --partial "Running: php admin/tool/behat/cli/run.php"
    assert_output --partial "Running single behat site:"
    assert_output --partial "4 scenarios (4 failed)"
    assert_output --partial "== Main run exit code: 1"
    assert_output --partial "== Rerun 1 of process 1 exit code: 1"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "== Exit code: 1"
}

@test "Behat tests: run the job for main with name applied" {
    # Set all the required variables.
    JOBTYPE="behat"
    DBTYPE="sqlsrv"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    BEHAT_NAME="the label"
    PLUGINSTOINSTALL="https://github.com/moodlehq/moodle-local_codechecker.git|local_codechecker|main"

    # Checkout main
    run git_moodle_checkout main
    assert_success

    # Run the job
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: behat"
    assert_output --partial "== PHP version: "
    assert_output --partial "== DBTYPE: sqlsrv"
    assert_output --partial "== BEHAT_NAME: the label"
    assert_output --partial "== DBREPLICAS: 0"
    assert_output --partial "== BEHAT_PARALLEL: 1"
    assert_output --partial "PLUGINSTOINSTALL: https://github.com/moodlehq/moodle-local_codechecker.git|"
    assert_output --partial "Cloning https://github.com/moodlehq/moodle-local_codechecker.git/main"
    assert_output --partial "Axe accessibility tests are enabled by default"
    assert_output --partial "Setting up docker-mocks module..."
    assert_output --partial "Setting up docker-selenium module..."
    assert_output --partial "Acceptance tests site installed"
    assert_output --partial "Running: php admin/tool/behat/cli/run.php"
    assert_output --partial "== Exit code: 0"
}
