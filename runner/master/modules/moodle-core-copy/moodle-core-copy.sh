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

# Moodle core (copy) module functions.

# This module defines the following env variables.
function moodle-core-copy_env() {
    env=(
        MOODLE_BRANCH
    )
    echo "${env[@]}"
}

# Moodle core copy module checks.
function moodle-core-copy_check() {
    # Check all module dependencies.
    verify_modules docker plugins docker-php

    # These env variables must be set for the module to work.
    verify_env BASEDIR CODEDIR PLUGINSDIR WEBSERVER
}

# Moodle core copy module config.
function moodle-core-copy_config() {
    # Get the Moodle branch from code, so we can make decisions based on it.
    MOODLE_BRANCH=$(grep "\$branch" "${CODEDIR}"/version.php | sed "s/';.*//" | sed "s/^\$.*'//")
}

# Moodle core copy module setup.
function moodle-core-copy_setup() {

    echo ">>> startsection Copying source files <<<"
    echo "============================================================================"

    # Copy the code to the web server.
    echo "== Copying code in place."
    docker cp "${CODEDIR}"/. "${WEBSERVER}":/var/www/html

    # Copy the config.php in place
    echo "== Copying configuration in place."
    docker cp "${BASEDIR}/modules/docker-php/config.template.php" "${WEBSERVER}":/var/www/html/config.php

    # Copy the plugins in place.
    if [[ -n "$PLUGINSTOINSTALL" ]]; then
      echo "== Copying external plugins in place."
      docker cp "${PLUGINSDIR}"/. "${WEBSERVER}":/var/www/html
    fi

    # Copy composer-phar if available in caches.
    if [[ -f "${COMPOSERCACHE}/composer.phar" ]]; then
      echo "== Copying composer.phar in place."
      docker cp "${COMPOSERCACHE}/composer.phar" "${WEBSERVER}":/var/www/html/composer.phar
    fi

    echo "============================================================================"
    echo ">>> stopsection <<<"
}