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

# Docker selenium module functions.

# This module defines the following env variables.
function docker-selenium_env() {
    env=(
        SELVERSION
        SELENIUMURL_1 # Allow up to 10 selenium urls.
        SELENIUMURL_2
        SELENIUMURL_3
        SELENIUMURL_4
        SELENIUMURL_5
        SELENIUMURL_6
        SELENIUMURL_7
        SELENIUMURL_8
        SELENIUMURL_9
        SELENIUMURL_10

        TRY_SELENIARM # Only for testing purposes, decide if we want to try arm64/aarch64 images.
        USE_SELVERSION
    )
    echo "${env[@]}"
}

# Docker selenium module checks.
function docker-selenium_check() {
    # Check all module dependencies.
    verify_modules docker browser

    # These env variables must be set for the module to work.
    verify_env NETWORK UUID CODEDIR SHAREDDIR BEHAT_PARALLEL BROWSER
}

# Docker selenium module config.
function docker-selenium_config() {
    # Apply default values for the module variables.
    SELVERSION=${SELVERSION:-3.141.59}

    # Only for testing purposes, decide if we want to try arm64/aarch64 images.
    # TODO: After testing, consider if we can make this the default for arm64, removing this conf.
    TRY_SELENIARM=${TRY_SELENIARM:-}

    # TODO: Remove once SELVERSION is used by default in Chrome.
    USE_SELVERSION=${USE_SELVERSION:-}

    # If, for any reason, BEHAT_PARALLEL is not a number or it's 0, we set it to 1.
    if [[ ! ${BEHAT_PARALLEL} =~ ^[0-9]+$ ]] || [[ ${BEHAT_PARALLEL} -eq 0 ]]; then
        print_warning "BEHAT_PARALLEL is not a number or it's 0, setting it to 1."
        BEHAT_PARALLEL=1
    fi

    # If the user has requested > 10 parallel runs, we reduce that to 10.
    if [[ ${BEHAT_PARALLEL} -gt 10 ]]; then
        print_warning "BEHAT_PARALLEL is set to ${BEHAT_PARALLEL}, but we only support up to 10 parallel runs."
        BEHAT_PARALLEL=10
    fi

    # Define all the SELENIUMURL_X urls.
    local iter=1
    while [[ ${iter} -le ${BEHAT_PARALLEL} ]]; do
        local selname=selenium"${iter}${UUID}"
        local selurl="http://${selname}:4444"
        declare -g "SELENIUMURL_${iter}=${selurl}"
        iter=$((iter+1))
    done
}

# Docker selenium module setup.
function docker-selenium_setup() {
    echo
    echo ">>> startsection Starting selenium servers (${BEHAT_PARALLEL})<<<"
    echo "============================================================================"

    # Use these images and options for the different browsers.
    # Chrome
    local chromeimage="selenium/standalone-chrome:${SELVERSION}"
    local chromeoptions="--shm-size=2g"
    # Firefox
    local firefoximage="selenium/standalone-firefox:${SELVERSION}"
    local firefoxoptions="--shm-size=2g"

    # Temporarily switching to custom image to include our bugfix for zero size failures.
    # TODO: Remove this once we can start using upstream images (selenium 4 or later).
    chromeimage="moodlehq/selenium-standalone-chrome:96.0-moodlehq"

    if [[ -n ${USE_SELVERSION} ]] && {
        [[ ${USE_SELVERSION,,} == "true" ]] || {
             [[ ${USE_SELVERSION} =~ ^[0-9]+$ ]] && [[ ${USE_SELVERSION} -gt 0 ]]; }; }; then
        chromeimage="selenium/standalone-chrome:${SELVERSION}"
    fi

    # Only for testing purposes, we are going to introduce basic support for arm64 architecture.
    # Many of the docker images already are multi-arch, but not the selenium ones, that are using
    # a different repository for arm64. Let's use them here.
    # Important note: While we are still running Selenium 3, the arm64 images are using Selenium 4,
    # so they could come with new problems or incompatibilities.
    # As said, this is only for testing purposes, we are not going to support arm64 officially yet.
    # TODO: After testing, consider if we can make this the default for arm64, deleting this conf.
    # and using the seleniarm images when `uname -m` is arm64 or aarch64.
    if [[ -n ${TRY_SELENIARM} ]]; then
        chromeimage="seleniarm/standalone-chromium:latest"
        firefoximage="sseleniarm/standalone-firefox:latest"
    fi

    # And these are the final images and options we will use.
    local browserimage=
    local browseroptions=

    if [[ ${BROWSER} == "chrome" ]]; then
        browserimage=${chromeimage}
        browseroptions=${chromeoptions}
    elif [[ ${BROWSER} == "firefox" ]]; then
        browserimage=${firefoximage}
        browseroptions=${firefoxoptions}
    fi

    # Start the selenium servers, only if the browser used requires it.
    if [[ -n ${browserimage} ]]; then
        local iter=1
        while [[ ${iter} -le ${BEHAT_PARALLEL} ]]; do
            local selname=selenium"${iter}${UUID}"
            echo
            echo ">>> Selenium ${iter} at $(date) <<<"
            docker run \
                --network "${NETWORK}" \
                --name "${selname}" \
                --detach \
                ${browseroptions} \
                -v "${CODEDIR}":/var/www/html \
                "${browserimage}"

            local varname="SELENIUMURL_${iter}"
            echo "Selenium ${iter} URL: ${!varname}"
            echo "Selenium ${iter} logs:"
            docker logs "${selname}"
            iter=$((iter+1))
        done
    else
        echo "No selenium server required for this browser: ${BROWSER}"
    fi

    echo "============================================================================"
    echo ">>> stopsection <<<"
}
