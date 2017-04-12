#!/bin/bash
##########################################
# This script will delete screenshots/logs
# Older than 5 days.
##########################################

# Diretory where files will be available.
homedir=/store
DAYS_TO_KEEP_LOGS=5

# Remove selenium logs older than 5 days
#cd $homedir/selenium_logs
#find . -mtime +5 -type f | xargs rm -rf

# Remove phantomjs logs older than 5 days.
cd $homedir/phantomjs_logs
find . -mtime +${DAYS_TO_KEEP_LOGS} -type f | xargs rm -rf

# Remove faildumps older than 5 days.
cd $homedir/moodledata/behatfaildump/behat_whole_suite_m_chrome
find . -mtime +${DAYS_TO_KEEP_LOGS} -type f | xargs rm -rf

cd $homedir/moodledata/behatfaildump/behat_whole_suite_m_parallel
find . -mtime +${DAYS_TO_KEEP_LOGS} -type f | xargs rm -rf

cd $homedir/moodledata/behatfaildump/behat_whole_suite_m_phantom
find . -mtime +${DAYS_TO_KEEP_LOGS} -type f | xargs rm -rf

exit 0
