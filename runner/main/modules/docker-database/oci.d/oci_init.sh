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
function oci_config_standalone() {
    echo "Starting standalone database..."
    # Need to adjust how we use tmpfs database depending on the database tag.
    local tmpfsinit=()
    local tmpfsmount=()
    if [[ "${DBTAG}" == "11" ]]; then
        tmpfsinit=(
            "-v"
            "${BASEDIR}/modules/docker-database/oci.d/tmpfs.sh:/docker-entrypoint-initdb.d/tmpfs.sh"
        )
        tmpfsmount=(
            "--tmpfs"
            "/var/lib/oracle"
            "--shm-size"
            "2g"
        )
    else
        # Let's mount the whole (XE/FREE) data directory  using tmpfs and
        # use it. Mounting individual databases doesn't work because of
        # a recent change in the upstream images from zip to 7z, later
        # causing issues with the database creation.
        # See https://github.com/gvenzl/oci-oracle-xe/issues/202
        # Until then we'll be mounting the whole data directory.
        tmpfsmount=(
            "--mount"
            "type=tmpfs,destination=/opt/oracle/oradata"
            "--shm-size"
            "6g"
        )
    fi

    docker run \
        --detach \
        --name "${DBHOST}" \
        --network "${NETWORK}" \
        "${tmpfsinit[@]}" "${tmpfsmount[@]}" \
        -e ORACLE_DISABLE_ASYNCH_IO=true \
        moodlehq/moodle-db-oracle-r2:"${DBTAG}"

    # Wait few secs, before executing commands.
    # TODO: Find a better way to wait for the database to be ready.
    sleep 140
}