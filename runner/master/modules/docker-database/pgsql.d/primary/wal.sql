--- WAL / replication settings
ALTER SYSTEM SET wal_level TO 'replica';
ALTER SYSTEM SET synchronous_commit TO 'local';
ALTER SYSTEM SET max_replication_slots = 2;
ALTER SYSTEM SET max_wal_senders TO 4;
ALTER SYSTEM SET synchronous_standby_names TO 1;

SELECT * FROM pg_create_physical_replication_slot('replica1');
