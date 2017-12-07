#!/usr/bin/env bash

set -e

i=0
# Wait for the SQL Server to come up.
until nc -z -w2 127.0.0.1 1433
do
    echo "[moodle-db-mssql] Waiting 5s for mssql to come up setup"
    sleep 5
    i=$((i+1))
    if [ $i -gt 60 ]; then
        echo "[moodle-db-mssql] timed out waiting for server to come up after 5 mins"
        exit 1;
    fi
done
echo "[moodle-db-mssql] SQL Server UP"
