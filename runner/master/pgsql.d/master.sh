#!/bin/bash

set -e

if [ "${DBHOST_SLAVE}" = "" ]
then
  echo "Not a postgres master in master/slave cluster"
  exit 0
fi

# Load docker-entrypoint helpers
source /docker-entrypoint.sh

docker_temp_server_stop

CONFFILE="$PGDATA"/postgresql.conf
HBAFILE="$PGDATA"/pg_hba.conf
ARCHIVEDIR="${PGDATA}/archive/"

# Create the archive directory for WAL logs.
mkdir -p "${ARCHIVEDIR}"
chmod 700 "${ARCHIVEDIR}"
chown -R postgres:postgres "${ARCHIVEDIR}"

# Configure the postgresql.conf for hot standby and more logging.
cat << EOF >> $CONFFILE

shared_buffers = 2GB
work_mem = 128MB
maintenance_work_mem = 256MB
effective_cache_size = 4GB
checkpoint_completion_target = 0.1
bgwriter_lru_maxpages = 0

wal_level = hot_standby
synchronous_commit = local
archive_mode = on
archive_command = 'cp %p ${ARCHIVEDIR}%f'
max_wal_senders = 4
max_replication_slots = 2
wal_keep_segments = 32
synchronous_standby_names = '${DBHOST_SLAVE}'

#log_statement = 'all'
log_directory = 'log'
log_filename = 'postgres.log'
logging_collector = on
log_min_error_statement = error
EOF

# Trust the world.
cat << EOF >> $HBAFILE
# Localhost
local   replication     $POSTGRES_USER                                trust

# PostgreSQL Master IP address
host    replication     $POSTGRES_USER        127.0.0.1/32            trust

# PostgreSQL SLave IP address
host    replication     $POSTGRES_USER        127.0.0.1/0             trust
EOF

docker_temp_server_start

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT * FROM pg_create_physical_replication_slot('${DBHOST_SLAVE}');
EOSQL
