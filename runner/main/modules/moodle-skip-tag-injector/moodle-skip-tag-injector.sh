#!/bin/bash

# The purpose of this module is to inject the @skip tag to flaky tests using the moodle-skip-tag-injector tool.
# For more information, see: https://github.com/moodlehq/moodle-skip-tag-injector/

# Define environment variables for the module.
function moodle-skip-tag-injector_env() {
    env=(
        FLAKY_SCENARIOS_FILE
        PATHTOSKIPTAGINJECTOR
    )
    echo "${env[@]}"
}

# Perform checks for the module.
function moodle-skip-tag-injector_check() {
    verify_env SHAREDDIR BROWSER MOODLE_BRANCH
}

function moodle-skip-tag-injector_config() {

    # Verifies whether the PATHTOSKIPTAGINJECTOR environment variable is set.
    if [[ -z "${PATHTOSKIPTAGINJECTOR}" ]]; then
        echo "Warning: PATHTOSKIPTAGINJECTOR not defined. Skipping the skip tag injector."
        return
    fi

    # Check if PATHTOSKIPTAGINJECTOR exists and is a directory.
    if [[ ! -d "${PATHTOSKIPTAGINJECTOR}" ]]; then
        echo "Error: PATHTOSKIPTAGINJECTOR '${PATHTOSKIPTAGINJECTOR}' does not exist or is not a directory, skipping."
        return
    fi

    # Check if the script exists.
    SKIP_TAG_INJECTOR_SCRIPT="${PATHTOSKIPTAGINJECTOR}/inject_skip_tag"
    if [[ ! -x "${SKIP_TAG_INJECTOR_SCRIPT}" ]]; then
        echo "Error: Script '${SKIP_TAG_INJECTOR_SCRIPT}' not found or not executable."
        return
    fi

    # Use the BROWSER environment variable.
    if [[ -z "${BROWSER}" ]]; then
        echo "Error: BROWSER environment variable is not set."
        return
    fi

    # Call the script for the specified branch and browser.
    echo "Processing flaky tests for branch: ${MOODLE_BRANCH}, browser: ${BROWSER}..."
    "${SKIP_TAG_INJECTOR_SCRIPT}" "${MOODLE_BRANCH}" "${BROWSER}" "${CODEDIR}"
}
