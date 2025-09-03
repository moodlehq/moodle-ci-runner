#!/bin/bash

# The purpose of this module is to skip flaky tests using the moodle-test-skipper tool.
# For more information, see: https://github.com/moodlehq/moodle-test-skipper/

# Define environment variables for the module.
function moodle-test-skipper_env() {
    env=(
        PATHTOTESTSKIPPER
    )
    echo "${env[@]}"
}

# Perform checks for the module.
function moodle-test-skipper_check() {
    verify_env SHAREDDIR MOODLE_BRANCH JOBTYPE BROWSER
}

function moodle-test-skipper_config() {

    # Verifies whether the PATHTOTESTSKIPPER environment variable is set.
    if [[ -z "${PATHTOTESTSKIPPER}" ]]; then
        echo "Warning: PATHTOTESTSKIPPER not defined. Skipping the test skipper."
        return
    fi

    # Check if PATHTOTESTSKIPPER exists and is a directory.
    if [[ ! -d "${PATHTOTESTSKIPPER}" ]]; then
        echo "Error: PATHTOTESTSKIPPER '${PATHTOTESTSKIPPER}' does not exist or is not a directory, skipping."
        return
    fi

    # Check if the main orchestrator script exists and is executable.
    SKIPPER_SCRIPT="${PATHTOTESTSKIPPER}/skip_tests"
    if [[ ! -x "${SKIPPER_SCRIPT}" ]]; then
        echo "Error: Script '${SKIPPER_SCRIPT}' not found or not executable."
        return
    fi

    # Route the execution based on the JOBTYPE.
    case "${JOBTYPE}" in
        behat)
            # A Behat run requires the BROWSER variable.
            if [[ -z "${BROWSER}" ]]; then
                echo "Error: BROWSER environment variable is not set for a 'behat' test type."
                return
            fi
            echo "Processing flaky Behat tests for branch: ${MOODLE_BRANCH}, browser: ${BROWSER}..."
            "${SKIPPER_SCRIPT}" behat "${MOODLE_BRANCH}" "${BROWSER}" "${CODEDIR}"
            ;;
        phpunit)
            echo "Processing flaky PHPUnit tests for branch: ${MOODLE_BRANCH}..."
            "${SKIPPER_SCRIPT}" phpunit "${MOODLE_BRANCH}" "${CODEDIR}"
            ;;
        *)
            echo "Warning: Unknown JOBTYPE '${JOBTYPE}'. Skipping flaky test injection."
            ;;
    esac
}
