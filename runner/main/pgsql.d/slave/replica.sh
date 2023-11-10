#!/bin/bash

set -e

PGPASSWORD=${POSTGRES_PASSWORD}
PGDATA=/var/lib/postgresql/data

echo "Polling until master is available"
until psql -h ${DBHOST} -U ${POSTGRES_USER} ${POSTGRES_DB} -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

echo "Stopping replica service to copy from master"
pg_ctl stop

echo "Cleaning replica PGDATA (${PGDATA})"
rm -fr ${PGDATA}/*

echo "Restoring PGDATA backup from master"
pg_basebackup -h ${DBHOST} -U ${POSTGRES_USER} -D "${PGDATA}" -P --wal-method=stream --slot=replica1 -R

echo "Starting replica service after copy from master"
pg_ctl start
