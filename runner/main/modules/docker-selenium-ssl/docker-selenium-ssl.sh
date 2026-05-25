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

# Docker selenium SSL module functions.

# This module defines the following env variables.
function docker-selenium-ssl_env() {
    env=(
    )
    echo "${env[@]}"
}

# Docker selenium module checks.
function docker-selenium-ssl_check() {
    # Check all module dependencies.
    verify_modules docker-selenium

    verify_env BROWSER UUID WEBSERVER
}

# Docker selenium module setup.
function docker-selenium-ssl_setup() {
    echo
    echo ">>> startsection Configuring selenium servers SSL (${BEHAT_PARALLEL})<<<"
    echo "============================================================================"

    local supported=
    if [[ ${BROWSER} == "chrome" ]]; then
        supported=1
    elif [[ ${BROWSER} == "firefox" ]]; then
        supported=1
    fi

    # Start the selenium servers, only if the browser used requires it.
    if [[ -n ${supported} ]]; then
        local iter=1
        while [[ ${iter} -le ${BEHAT_PARALLEL} ]]; do
            local selname=selenium"${iter}${UUID}"
            echo
            echo ">>> Selenium ${iter} at $(date) <<<"
            docker exec "${selname}" mkdir -p /tmp/cert && curl "http://${WEBSERVER}/certificate/certificate.pem" > /tmp/cert/certificate.pem && /opt/bin/add-cert-helper.sh -d /tmp/cert

            iter=$((iter+1))
        done
    else
        echo "No selenium server required for this browser: ${BROWSER}"
    fi

    echo "============================================================================"
    echo ">>> stopsection <<<"
}
