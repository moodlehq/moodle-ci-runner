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

# Run the tests for the rector job type.

# Where the fixture with Rector changes pending is copied to, within the Moodle checkout.
FIXTUREPATH="public/lib/tests/rector_fixture_test.php"

setup() {
    load 'helpers/common'
    _common_setup
}

teardown() {
    load 'helpers/common'
    # The fixture is untracked, so the checkout in _common_teardown does not remove it.
    rm -f "${MOODLE_CI_RUNNER_GITDIR}/${FIXTUREPATH}"
    _common_teardown
}

@test "Rector tests: run the job for main" {
    # Set all the required variables.
    JOBTYPE="rector"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    # Restrict the run to a known clean file. Checking the whole codebase would
    # make this test fail whenever core itself has pending Rector changes.
    RECTOR_PATHS="public/lib/tests/component_test.php"

    # Checkout main
    run git_moodle_checkout main
    assert_success

    # Run the job
    run launch_runner
    assert_success
    assert_output --partial "== JOBTYPE: rector"
    assert_output --partial "== Moodle branch (version.php):"
    assert_output --partial "== PHP version: 8.3"
    assert_output --partial "== RECTOR_PATHS: public/lib/tests/component_test.php"
    assert_output --partial "Installing composer dependencies (including Rector)"
    assert_output --partial "Running: php -d memory_limit=-1 vendor-bin/rector/vendor/rector/rector/bin/rector process --dry-run --no-progress-bar --memory-limit=-1 public/lib/tests/component_test.php"
    assert_output --partial "[OK] Rector is done!"
    assert_output --partial "Exporting all docker logs for UUID"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "== Exit code: 0"
}

@test "Rector tests: the job fails when Rector would change code" {
    # Set all the required variables.
    JOBTYPE="rector"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    # Restrict the run to the fixture and a clean file, to save time.
    RECTOR_PATHS="${FIXTUREPATH},public/lib/tests/component_test.php"
    RECTOR_MAX_PROCS=2

    # Checkout main and add a test still using the @dataProvider annotation.
    run git_moodle_checkout main
    assert_success
    cp "${RUNNER_DIR}/test/fixtures/rector/rector_fixture_test.php" "${MOODLE_CI_RUNNER_GITDIR}/${FIXTUREPATH}"

    # Run the job
    run launch_runner
    assert_failure
    assert_output --partial "== JOBTYPE: rector"
    assert_output --partial "== RECTOR_PATHS: ${FIXTUREPATH},public/lib/tests/component_test.php"
    assert_output --partial "== RECTOR_MAX_PROCS: 2"
    assert_output --partial "rector process --dry-run --no-progress-bar --memory-limit=-1 ${FIXTUREPATH} public/lib/tests/component_test.php"
    assert_output --partial "1 file with changes"
    assert_output --partial "#[\PHPUnit\Framework\Attributes\DataProvider('values_provider')]"
    assert_output --partial "DataProviderAnnotationToAttributeRector"
    assert_output --partial "1 file would have been changed (dry-run) by Rector"
    assert_output --partial "Stopping and removing all docker containers"
    assert_output --partial "== Exit code: 2"
}

@test "Rector tests: the job stops on branches without Rector" {
    # Set all the required variables.
    JOBTYPE="rector"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"

    # Checkout a release from before Rector was added to core (MDL-84204).
    run git_moodle_checkout v5.1.0
    assert_success

    # Run the job
    run launch_runner
    assert_failure
    assert_output --partial "No rector.php found in ${CODEDIR}"
    assert_output --partial "Rector is only supported in Moodle 6.0 and up (MDL-84204)."
}

@test "Rector tests: the job stops with an invalid RECTOR_MAX_PROCS" {
    # Set all the required variables.
    JOBTYPE="rector"
    CODEDIR="${MOODLE_CI_RUNNER_GITDIR}"
    RECTOR_MAX_PROCS="many"

    # Checkout main
    run git_moodle_checkout main
    assert_success

    # Run the job
    run launch_runner
    assert_failure
    assert_output --partial "RECTOR_MAX_PROCS must be a positive integer, got: many"
}
