#!/bin/sh

backupdate=`date +%Y%M%d_%H%m%S`
backupfile="/store/jenkins/backups/config_backup_$backupdate.tgz"

echo "Backing up /var/lib/jenkins to $backupfile"
find /var/lib/jenkins -iname 'config.xml' | tar -czf "$backupfile" --files-from -
