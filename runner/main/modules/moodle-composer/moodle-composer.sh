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

# Moodle module functions for Composer-based Moodle installations.

# This module defines the following env variables.
function moodle-composer_env() {
    env=(
    )
    echo "${env[@]}"
}

# Moodle composer module checks.
function moodle-composer_check() {
    # These env variables must be set for the module to work.
    verify_env CODEDIR

    # We can't verify the WEBSERVER env variable here, as the _check method
    # is executed before the docker-php_setup method that defines it.
}

# Moodle composer module config.
function moodle-composer_setup() {
    if [[ "${COMPOSERINSTALL}" != "1" ]]; then
        return
    fi

    # Install composer.
    docker cp "${BASEDIR}/modules/moodle-composer/install-composer.sh" "${WEBSERVER}":/tmp/install-composer.sh
    docker exec -u root "${WEBSERVER}" bash -c "chmod +x /tmp/install-composer.sh ; /tmp/install-composer.sh"

    # Create a composer.json.
    echo "Copying composer.json to the web server."
    docker cp "${BASEDIR}/modules/moodle-composer/composer.json" "${WEBSERVER}":${PHPWORKINGDIR}/composer.json
    docker exec -u root "${WEBSERVER}" bash -c "sed -i '/require.*setup.php/d' ${PHPWORKINGDIR}/config.php"

    # Configure composer.
    docker exec \
        "${WEBSERVER}" \
        git config --global --add safe.directory /var/www/html

    # Run composer install.
    echo "Running composer install. This may take a while..."
    docker exec \
        -u www-data \
        "${WEBSERVER}" \
        bash -c "composer install --no-interaction --prefer-dist --optimize-autoloader"
    echo "Composer install finished"
}
