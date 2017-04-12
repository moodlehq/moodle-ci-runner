#!/bin/bash

set -e

# Diretory where files will be available.
homedir=/store

if [ -z "$1" ]; then
  echo "`basename $0` {start|stop}"
  exit
fi
# Get php port
if [ -n "$2" ]; then
    PHPPORT=$2
  else
    PHPPORT=8000
  fi

case "$1" in
start)
    php -S 127.0.0.1:$PHPPORT > /dev/null 2>&1 &
;;
stop)
  pid=$( ps -ef | grep "php -S 127.0.0.1:$PHPPORT" | grep -v grep | awk '{print $2}' )
  if [ ! -z "$pid" ]; then
    for process in $pid; do
      kill $process
    done;
  fi
;;
esac

