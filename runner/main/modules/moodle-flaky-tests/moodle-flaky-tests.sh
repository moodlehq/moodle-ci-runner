#!/bin/bash

# Moodle flaky tests module functions.

# Define environment variables for the module.
function moodle-flaky-tests_env() {
    env=(
        FLAKY_SCENARIOS_FILE
        PATHTOFLAKY
    )
    echo "${env[@]}"
}

# Perform checks for the module.
function moodle-flaky-tests_check() {
    verify_env SHAREDDIR BROWSER
}

function moodle-flaky-tests_config() {

    # Check if PATHTOFLAKY exists and is a directory.
    if [[ ! -d "${PATHTOFLAKY}" ]]; then
        echo "Error: PATHTOFLAKY '${PATHTOFLAKY}' does not exist or is not a directory."
        exit 1
    fi

    # Check if the script exists.
    FLAKY_TESTS_SCRIPT="${PATHTOFLAKY}/skip_flaky_tests"
    if [[ ! -x "${FLAKY_TESTS_SCRIPT}" ]]; then
        echo "Error: Script '${FLAKY_TESTS_SCRIPT}' not found or not executable."
        exit 1
    fi

    # Use the BROWSER environment variable.
    if [[ -z "${BROWSER}" ]]; then
        echo "Error: BROWSER environment variable is not set."
        exit 1
    fi

    # Call the script for the specified branch and browser.
    branch="main"
    echo "Processing flaky tests for branch: ${branch}, browser: ${BROWSER}..."
    "${FLAKY_TESTS_SCRIPT}" "${branch}" "${BROWSER}" "${CODEDIR}"
}

# Inject @flaky tags into test files.
function moodle-flaky-tests_setup() {
    echo ">>> startsection Injecting @flaky tags to Behat tests <<<"
    echo "============================================================================"



    echo "============================================================================"
    echo ">>> stopsection <<<"
}
