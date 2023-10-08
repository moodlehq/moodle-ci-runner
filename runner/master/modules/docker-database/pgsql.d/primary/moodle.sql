--- Tuning the primary server for performance
ALTER SYSTEM SET shared_buffers TO '2GB';
ALTER SYSTEM SET work_mem TO '128MB';
ALTER SYSTEM SET maintenance_work_mem TO '256MB';
ALTER SYSTEM SET effective_cache_size TO '4GB';
ALTER SYSTEM SET synchronous_commit TO 'off';
ALTER SYSTEM SET checkpoint_completion_target TO '0.9';
ALTER SYSTEM SET fsync TO 'off';
ALTER SYSTEM SET full_page_writes TO 'off';
ALTER SYSTEM SET bgwriter_lru_maxpages TO 0;
