#!/bin/bash

set -e

export DISPLAY=:99
# Diretory where files will be available.
homedir=/store

$homedir/scripts/xvfb.sh stop
$homedir/scripts/phantomjs.sh stop
$homedir/scripts/selenium.sh stop
$homedir/scripts/delete_old_logs.sh

exit 0
