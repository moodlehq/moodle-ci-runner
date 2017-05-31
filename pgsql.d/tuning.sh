#!/bin/sh

CONFFILE="$PGDATA"/postgresql.conf

echo 'shared_buffers = 2GB'         >> $CONFFILE
echo 'work_mem = 128MB'             >> $CONFFILE
echo 'maintenance_work_mem = 256MB' >> $CONFFILE
echo 'effective_cache_size = 4GB '  >> $CONFFILE
echo 'synchronous_commit = off'     >> $CONFFILE
echo 'checkpoint_completion_target = 0.9' >> $CONFFILE
echo 'fsync = off' >> $CONFFILE
echo 'full_page_writes = off' >> $CONFFILE
echo 'bgwriter_lru_maxpages = 0' >> $CONFFILE
