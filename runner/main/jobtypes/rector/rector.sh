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

# Rector job type functions.
#
# Runs Rector (https://getrector.com) in dry-run mode against the Moodle checkout,
# using the configuration shipped with Moodle core (rector.php, added by MDL-84204).
# The job fails if Rector would change any file, printing the diff of the changes.

# Directory, within the PHP container, where the Moodle checkout is copied to.
RECTOR_CODEROOT=/var/www/html

# Rector binary, relative to the Moodle checkout root. Installed by the
# composer post-install-cmd script (.rector/install.php) via composer-bin.
RECTOR_BIN=vendor-bin/rector/vendor/rector/rector/bin/rector

# Rector needed variables to go to the env file.
# Rector does not need a database or any other service, so this is empty.
function rector_to_env_file() {
    local env=()
    echo "${env[@]}"
}

# Rector information to be added to the summary.
function rector_to_summary() {
    echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
    echo "== PHP version: ${PHP_VERSION}"
    echo "== RECTOR_PATHS: ${RECTOR_PATHS}"
    echo "== RECTOR_MAX_PROCS: ${RECTOR_MAX_PROCS}"
}

# This job type defines the following env variables
function rector_env() {
    env=(
        RECTOR_PATHS
        RECTOR_MAX_PROCS
        EXITCODE
    )
    echo "${env[@]}"
}

# Rector needed modules. Note that the order is important.
# No database or any other service is needed, just a PHP container with the code.
function rector_modules() {
    local modules=(
        env
        summary
        moodle-branch
        docker
        docker-logs
        git
        plugins
        docker-php
        moodle-core-copy
        docker-healthy
        docker-summary
    )
    echo "${modules[@]}"
}

# Rector job type checks.
function rector_check() {
    # Check all module dependencies.
    verify_modules $(rector_modules)

    # These env variables must be set for the job to work.
    verify_env UUID WEBSERVER CODEDIR

    # Rector is only available in Moodle 6.0 and up (MDL-84204). Stop early
    # with a clear message if the checkout does not ship its configuration.
    if [[ ! -f "${CODEDIR}/rector.php" ]]; then
        exit_error "No rector.php found in ${CODEDIR}. Rector is only supported in Moodle 6.0 and up (MDL-84204)."
    fi
}

# Rector job type config.
function rector_config() {
    # Apply some defaults.
    # Empty RECTOR_PATHS means the paths defined in the rector.php config (the whole checkout).
    RECTOR_PATHS="${RECTOR_PATHS:-}"
    # Empty RECTOR_MAX_PROCS means the default defined in the rector.php config.
    RECTOR_MAX_PROCS="${RECTOR_MAX_PROCS:-}"
    EXITCODE=0

    if [[ -n "${RECTOR_MAX_PROCS}" ]] && [[ ! "${RECTOR_MAX_PROCS}" =~ ^[1-9][0-9]*$ ]]; then
        exit_error "RECTOR_MAX_PROCS must be a positive integer, got: ${RECTOR_MAX_PROCS}"
    fi
}

# Rector job type setup.
function rector_setup() {
    echo
    echo ">>> startsection Initialising Rector environment at $(date) <<<"
    echo "============================================================================"

    # The config.php copied by moodle-core-copy is not part of the checkout, and
    # Rector would analyse it (rector.php includes the root files). Remove it.
    docker exec "${WEBSERVER}" rm -f "${RECTOR_CODEROOT}/config.php"

    # Composer is not available in the PHP image, install it.
    echo "== Installing composer."
    docker cp "${BASEDIR}/modules/moodle-composer/install-composer.sh" "${WEBSERVER}":/tmp/install-composer.sh
    docker exec -u root -w /tmp "${WEBSERVER}" bash -c "chmod +x /tmp/install-composer.sh && /tmp/install-composer.sh"

    # Install the development dependencies. Moodle's post-install-cmd script
    # (.rector/install.php) then installs Rector under vendor-bin/rector.
    echo "== Installing composer dependencies (including Rector)."
    docker exec -u www-data -w "${RECTOR_CODEROOT}" "${WEBSERVER}" \
        composer install --no-interaction --no-progress --prefer-dist

    if ! docker exec -u www-data -w "${RECTOR_CODEROOT}" "${WEBSERVER}" test -f "${RECTOR_BIN}"; then
        exit_error "Rector was not installed at ${RECTOR_BIN} by composer install."
    fi

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Rector job type run.
function rector_run() {
    echo
    echo ">>> startsection Starting Rector run at $(date) <<<"
    echo "============================================================================"

    # Build the complete command.
    local runcmd
    rector_runcmd runcmd # By nameref.

    # RECTOR_MAX_PROCS is read by Moodle's rector.php config.
    local envopts=()
    if [[ -n "${RECTOR_MAX_PROCS}" ]]; then
        envopts=(-e "RECTOR_MAX_PROCS=${RECTOR_MAX_PROCS}")
    fi

    echo "Running: ${runcmd[*]}"
    echo

    # (the ${envopts[@]+...} form avoids "unbound variable" for empty arrays with set -u on bash < 4.4).
    docker exec -t -u www-data -w "${RECTOR_CODEROOT}" ${envopts[@]+"${envopts[@]}"} "${WEBSERVER}" "${runcmd[@]}"
    EXITCODE=$?

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Returns (by nameref) an array with the command needed to run Rector.
function rector_runcmd() {
    local -n cmd=$1
    # The PHP image defaults to 128M of memory, not enough for Rector over the whole codebase.
    # --dry-run makes Rector exit with an error and print the diff if any file would change.
    cmd=(
        php -d memory_limit=-1
        "${RECTOR_BIN}" process
        --dry-run
        --no-progress-bar
        --memory-limit=-1
    )
    if [[ -n "${RECTOR_PATHS}" ]]; then
        # Paths are relative to the Moodle checkout root, comma or space separated.
        local paths
        IFS=', ' read -r -a paths <<< "${RECTOR_PATHS}"
        cmd+=("${paths[@]}")
    fi
}
