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

# Browser module functions.

# This module defines the following env variables
function browser_env() {
    env=(
        BROWSER
        BROWSER_DEBUG
        BROWSER_HEADLESS
        BROWSER_CHROME_ARGS
        BROWSER_FIREFOX_ARGS
    )
    echo "${env[@]}"
}

# Browser module checks.
function browser_check() {
    # TODO: We can check here that the browser is one of the supported
    # by docker-selenium (chrome and firefox right now). But we cannot
    # forget non-js tests that can arrive with empty browser, because
    # they don't need selenium.
    # We don't have any dependencies.
    true
}

# Browser module config.
function browser_config() {
    # Apply some defaults.
    BROWSER="${BROWSER:-chrome}"
    BROWSER_DEBUG="${BROWSER_DEBUG:-}"
    BROWSER_HEADLESS="${BROWSER_HEADLESS:-}"
    BROWSER_CHROME_ARGS="${BROWSER_CHROME_ARGS:-}"
    BROWSER_FIREFOX_ARGS="${BROWSER_FIREFOX_ARGS:-}"
}
