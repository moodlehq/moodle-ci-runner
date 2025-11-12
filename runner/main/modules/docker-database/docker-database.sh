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

# Database module functions.

# This module defines the following env variables.
function docker-database_env() {
    env=(
        DBTYPE
        DBTAG
        DBREPLICAS
        DBHOST
        DBNAME
        DBUSER
        DBPASS
        DBCOLLATION
        DBHOST_DBREPLICA
    )
    echo "${env[@]}"
}

# Database module checks.
function docker-database_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the database module to work.
    verify_env NETWORK UUID
}

# Database module init.
function docker-database_config() {
    # Apply some defaults.
    DBTYPE="${DBTYPE:-pgsql}"
    DBTAG="${DBTAG:-auto}"
    DBREPLICAS="${DBREPLICAS:-0}"
    DBHOST=database"${UUID}"
    DBNAME="${DBNAME:-moodle}"
    DBUSER="${DBUSER:-moodle}"
    DBPASS="${DBPASS:-moodle}"
    DBCOLLATION="${DBCOLLATION:-}"
    if [[ "${DBREPLICAS}" -ne 0 ]]; then
        DBHOST_DBREPLICA="database_replica${UUID}"
    fi

    # Let's decide the DBTAG to use.
    database_apply_default_dbtag

    # Let's apply some configuration depending on DBTYPE / DBTAG...
    database_apply_config
}

# Database module setup, apply for the correct db tags and launch the containers.
function docker-database_setup() {

    # We are ready to launch the database containers. Each DBTYPE has its own way to be launched.
    local dbscript="${BASEDIR}/modules/docker-database/${DBTYPE}.d/${DBTYPE}_init.sh"
    if [[ ! -f "${dbscript}" ]]; then
        exit_error "Wrong DBTYPE: ${DBTYPE}. The ${dbscript} script does not exist."
    fi
    # shellcheck source=modules/docker-database/mysqli.d/pgsql_config.sh # (so we have a reliable database for other checks)
    source "${dbscript}"
    # Function to be executed to launch the database containers.
    local dbinitfunc="${DBTYPE}_config_standalone"
    # Replicas use a different one
    if [[ "${DBREPLICAS}" -ne 0 ]]; then
        dbinitfunc="${DBTYPE}_config_with_replicas"
    fi
    # The function must exist.
    if ! type "${dbinitfunc}" > /dev/null 2>&1; then
        exit_error "Database ${DBTYPE} does not have a ${dbinitfunc} function (at ${DBTYPE}.d/${DBTYPE}_config.sh)."
    fi

    # Launch the database containers.
    echo ">>> startsection Starting database <<<"
    echo "============================================================================"
    "${dbinitfunc}"
    echo "============================================================================"
    echo ">>> stopsection <<<"

    # Print the database logs
    echo
    echo ">>> startsection Database summary <<<"
    echo "============================================================================"
    echo "== DBTYPE: ${DBTYPE}"
    echo "== DBTAG: ${DBTAG}"
    echo "== DBHOST: ${DBHOST}"
    echo "== DBNAME: ${DBNAME}"
    echo "== DBUSER: ${DBUSER}"
    echo "== DBPASS: ${DBPASS}"
    echo "== DBCOLLATION: ${DBCOLLATION}"
    echo "== DBREPLICAS: ${DBREPLICAS}"
    if [[ -n "${DBHOST_DBREPLICA}" ]]; then
        echo "== DBHOST_DBREPLICA: ${DBHOST_DBREPLICA}"
    fi
    echo
    echo "Database logs:"
    docker logs "${DBHOST}"

    if [ "${DBHOST_DBREPLICA}" != "" ]
    then
        echo
        echo "Database replica logs:"
        docker logs "${DBHOST_DBREPLICA}"
    fi

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Let's decide the default DBTAG to use if none was specified.
function database_apply_default_dbtag() {
    # Here it's where we pin any DBTAG docker tag (versions), when needed. Don't change it elsewhere.
    # We only apply these pinned defaults when no DBTAG has been explicitly defined. And we only apply
    # them to databases know to need them (some bug prevents to use "latest"). Every pinned case should
    # include a comment with the reason for it.
    if [[ "${DBTAG}" == "auto" ]]; then
        case ${DBTYPE} in
            mariadb)
                DBTAG=10.11 # Because it's the primary lowest supported version and we need it covered by default.
                ;;
            mysqli)
                DBTAG=8.4 # Because it's the primary lowest supported version and we need it covered by default.
                ;;
            sqlsrv)
                DBTAG=latest # No pin, right now 2019-latest
                ;;
            oci)
                DBTAG=latest # No pin, right now this is 21c
                ;;
            pgsql)
                DBTAG=16 # Because it's the primary lowest supported version and we need it covered by default.
                ;;
            *)
                exit_error "Wrong DBTYPE: ${DBTYPE}. Fix it, or add support for that DBTYPE above"
                ;;
        esac
    fi
}

# Every DBTYPE / DBTAG ... combination may need some specific configuration.
function database_apply_config() {
    case ${DBTYPE} in
        mariadb)
            # MariaDB needs a collation.
            DBCOLLATION="${DBCOLLATION:-utf8mb4_bin}"
            ;;
        mysqli)
            # MySQLi needs a collation.
            DBCOLLATION="${DBCOLLATION:-utf8mb4_bin}"
            ;;
        sqlsrv)
            # These are the only ones working with our image.
            DBUSER="sa"
            DBPASS="Passw0rd!"
            ;;
        oci)
            # These are the only ones working with our image.
            DBPASS="m@0dl3ing"
            DBNAME="XE"
            if [[ "${DBTAG}" == "23" ]]; then
                # The Oracle 23 image is using the FREE database instead of the XE one.
                DBNAME="FREE"
            fi
            ;;
        pgsql)
            ;;
        *)
            exit_error "Wrong DBTYPE: ${DBTYPE}. Fix it, or add support for that DBTYPE above"
            ;;
    esac
}
