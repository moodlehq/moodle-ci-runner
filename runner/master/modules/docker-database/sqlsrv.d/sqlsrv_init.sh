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
# This database only supports standalone setups, not primary-replica ones.

# Init a standalone database container. Without replicas.
function sqlsrv_config_standalone() {
    echo "Starting standalone database..."
    docker run \
        --detach \
        --name "${DBHOST}" \
        --network "${NETWORK}" \
        -e ACCEPT_EULA=Y \
        -e SA_PASSWORD="${DBPASS}" \
        moodlehq/moodle-db-mssql:"${DBTAG}"

    # Wait few secs, before executing commands.
    # TODO: Find a better way to wait for the database to be ready.
    sleep 10
}