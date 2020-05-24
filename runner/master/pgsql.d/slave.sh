#!/bin/bash

if [ "${DBHOST}" = "" ]
then
  echo "Not a postgres slave in master/slave cluster"
  exit 0
fi

echo "Sleeping for a few seconds for background tasks to occur"
sleep 3
echo "Finished the sleep"

ls -Al /usr/local/bin/gosu
gosu root id

# Load docker-entrypoint helpers
source /docker-entrypoint.sh

ORIG=$PGDATA.orig
CONFFILE="$PGDATA"/postgresql.conf
HBAFILE="$PGDATA"/pg_hba.conf
ARCHIVEDIR="${PGDATA}/archive/"
RECOVERYCONF="${PGDATA}/recovery.conf"

# Stop the server before doing anything.
# This function comes courtesy of /docker-entrypoint.sh
docker_temp_server_stop

# Ensure that the postgresql data directory is owned by the postgres user.
# These scripts run as 'postgres' so we must use gosu to do so.
gosu root chown postgres:postgres /var/lib/postgresql
gosu root chown postgres:postgres $PGDATA

# Move the original PGDATA to a new location
mkdir -p "${ORIG}"
chmod 700 "${ORIG}"
chown -R postgres:postgres "${ORIG}"
mv $PGDATA/* $ORIG/

sleep 2

echo "Polling until master is available"
until psql -h ${DBHOST} -U moodle initial -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

echo "Restoring backup from master"
pg_basebackup -h ${DBHOST} -U moodle -D "${PGDATA}" -P --xlog-method=stream

echo "Copying postgresql.conf in place"
cp $PGDATA.orig/postgresql.conf $CONFFILE

# Set the postgres configuration for a slave.
echo "Configuring $CONFFILE as a slave"
cat << EOF >> $CONFFILE
hot_standby = on

log_directory = 'pg_log'
log_filename = 'postgres.log'
logging_collector = on
log_min_error_statement = error
EOF

echo "Copying recovery.conf in place"
cat << EOF >> "${RECOVERYCONF}"
standby_mode = 'on'
primary_conninfo = 'host=${DBHOST} port=5432 user=${POSTGRES_USER} application_name=${POSTGRES_DB}'
primary_slot_name = '${DBHOST_SLAVE}'
restore_command = 'cp ${ARCHIVEDIR}%f %p'
trigger_file = '/tmp/postgresql.trigger.5432'
EOF
chmod 600 "${RECOVERYCONF}"

# Restart postgres.
docker_temp_server_start
