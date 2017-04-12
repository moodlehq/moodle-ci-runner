#!/bin/bash

set -e

# Diretory where files will be available.
homedir=/store

# Create log directory if not present
mkdir -p $homedir/phantomjs_logs

if [ -z "$1" ]; then
  echo "`basename $0` {start|stop}"
  exit
fi

if [ -z "$2" ]; then
  PHANTOMPORT=4443
else
  PHANTOMPORT=$2
fi

case "$1" in
start)
  $homedir/behatdrivers/phantomjs --webdriver=$PHANTOMPORT &> $homedir/phantomjs_logs/`date '+%Y%m%d_%H%M'`.log &
  #$homedir/behatdrivers/phantomjs --webdriver=4443 --webdriver-logfile=$homedir/phantomjs_logs/webdriver_`date '+%Y%m%d_%H%M'`.log --webdriver-loglevel=DEBUG &> $homedir/phantomjs_logs/`date '+%Y%m%d_%H%M'`.log &
;;
stop)
  pid=$( ps -ef | grep "/behatdrivers/phantomjs --webdriver=$PHANTOMPORT" | grep -v grep | awk '{print $2}' )
  if [ ! -z "$pid" ]; then
    kill $pid
  fi
;;
esac

