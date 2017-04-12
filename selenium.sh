#!/bin/bash

set -e

# Diretory where files will be available.
homedir=/store

# Create log directory if not present.
mkdir -p $homedir/selenium_logs

if [ -z "$1" ]; then
  echo "`basename $0` {start|stop}"
  exit
fi

if [ -z "$2" ]; then
  SELENIUMPORT=4444
else
  SELENIUMPORT=$2
fi

case "$1" in
start)
   xvfb-run -a --server-args='-screen 0 2500x1600x24' java -jar $homedir/behatdrivers/selenium-server-standalone-2.53.1.jar -port $SELENIUMPORT &> $homedir/selenium_logs/`date '+%Y%m%d_%H%M'`.log &;;
stop)
  pid=$( ps -ef | grep "behatdrivers/selenium-server-standalone-2.53.1.jar -port $SELENIUMPORT" | grep -v grep | awk '{print $2}' )
  if [ ! -z "$pid" ]; then
    kill $pid
  fi
;;
esac

