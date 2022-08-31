#!/bin/bash

set -e

HBAFILE=/var/lib/postgresql/data/pg_hba.conf

cat << EOF >> ${HBAFILE}
host	replication	${POSTGRES_USER}		samenet			md5
EOF
