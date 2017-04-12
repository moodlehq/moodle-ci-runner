#!/bin/bash

set -e

export DISPLAY=:99

# Diretory where files will be available.
homedir=/store

$homedir/scripts/xvfb.sh start
$homedir/scripts/selenium_phantom.sh start
$homedir/scripts/phantomjs.sh start

exit 0
