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

# LDAP module functions.

# This module defines the following env variables.
function docker-ldap_env() {
    env=(
        LDAPTESTURL
    )
    echo "${env[@]}"
}

# LDAP module checks.
function docker-ldap_check() {
    # Check all module dependencies.
    verify_modules docker

    # These env variables must be set for the database module to work.
    verify_env NETWORK UUID
}

# LDAP module config.
function docker-ldap_config() {
    LDAP=ldap"${UUID}"
    LDAPTESTURL="ldap://${LDAP}"
}

# LDAP module setup, launch the containers.
function docker-ldap_setup() {
    echo
    echo ">>> startsection Starting LDAP server <<<"
    echo "============================================================================"

    # Start the ldap server
    docker run \
        --detach \
        --name "${LDAP}" \
        --network "${NETWORK}" \
        larrycai/openldap

    echo "LDAP: URL: ${LDAPTESTURL}"
    echo "LDAP logs:"
    docker logs "${LDAP}"

    echo "============================================================================"
    echo ">>> stopsection <<<"
}