#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "`basename $0` {start|stop}"
  exit
fi

case "$1" in
start)
  /usr/bin/Xvfb :99 -ac -screen 0 1024x768x8 &
;;
stop)
  pid=$( ps -ef | grep /usr/bin/Xvfb | grep -v grep | awk '{print $2}' )
  if [ ! -z "$pid" ]; then
    kill $pid
  fi
;;
esac

