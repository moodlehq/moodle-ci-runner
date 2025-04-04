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

# Functions needed to init the database.
# This database supports both standalone and primary-replica setups.

# Init a standalone database container. Without replicas.
function mariadb_config_standalone() {
    echo "Starting standalone database..."
    docker run \
        --detach \
        --name "${DBHOST}" \
        --network "${NETWORK}" \
        -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
        -e MYSQL_DATABASE="${DBNAME}" \
        -e MYSQL_USER="${DBUSER}" \
        -e MYSQL_PASSWORD="${DBPASS}" \
        --tmpfs /var/lib/mysql:rw,noexec,nosuid,size=4096m \
        -v "${BASEDIR}/modules/docker-database/mariadb.d/standalone/conf.d:/etc/mysql/conf.d" \
        mariadb:"${DBTAG}"

    # Wait few secs, before executing commands.
    # TODO: Find a better way to wait for the database to be ready.
    sleep 20
}

# Init a primary  database container. With replicas.
function mariadb_config_with_replicas() {
    echo "Starting primary database..."
    docker run \
        --detach \
        --name "${DBHOST}" \
        --network "${NETWORK}" \
        -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
        -e MYSQL_DATABASE="${DBNAME}" \
        -e MYSQL_USER="${DBUSER}" \
        -e MYSQL_PASSWORD="${DBPASS}" \
        -e DBHOST_DBREPLICA="${DBHOST_DBREPLICA}" \
        --tmpfs /var/lib/mysql:rw,noexec,nosuid,size=4096m \
        -v "${BASEDIR}/modules/docker-database/mariadb.d/primary/conf.d:/etc/mysql/conf.d" \
        -v "${BASEDIR}/modules/docker-database/mariadb.d/primary/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d" \
        mariadb:"${DBTAG}"

    # Wait few secs, before executing commands.
    # TODO: Find a better way to wait for the database to be ready.
    sleep 20

    echo "Starting replica database..."
    docker run \
        --detach \
        --name "${DBHOST_DBREPLICA}" \
        --network "${NETWORK}" \
        -e MYSQL_ROOT_PASSWORD="${DBPASS}" \
        -e MYSQL_DATABASE="${DBNAME}" \
        -e MYSQL_USER="${DBUSER}" \
        -e MYSQL_PASSWORD="${DBPASS}" \
        -e DBHOST="${DBHOST}" \
        -e DBHOST_DBREPLICA="${DBHOST_DBREPLICA}" \
        -v "${BASEDIR}/modules/docker-database/mariadb.d/replica/conf.d:/etc/mysql/conf.d" \
        -v "${BASEDIR}/modules/docker-database/mariadb.d/replica/docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d" \
        --tmpfs /var/lib/mysql:rw,noexec,nosuid,size=4096m \
        mariadb:"${DBTAG}"

    # Wait few secs, before executing commands.
    # TODO: Find a better way to wait for the database to be ready.
    sleep 20
}
