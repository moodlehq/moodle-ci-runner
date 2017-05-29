#!/bin/sh

backupdate=`date +%Y%M%d_%H%m%S`
backupfile="/store/jenkins/backups/backup_$backupdate.tgz"

cd /var/lib
echo "Backing up /var/lib/jenkins to $backupfile"
sudo tar \
  --exclude='jenkins/shared'\
  --exclude='jenkins/.composer'\
  --exclude='jenkins/firefox*'\
  --exclude='jenkins/Downloads'\
  --exclude='jenkins/.dbus' \
  -czf \
  "$backupfile" \
  jenkins
