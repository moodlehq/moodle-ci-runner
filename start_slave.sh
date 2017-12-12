#!/usr/bin/env bash
set -e
set -u
set -x

if [ -f /var/lib/jenkins/.config/jenkins ]
then
  source /var/lib/jenkins/.config/jenkins
fi

JENKINSURL="${JENKINSURL:-https://ci.moodle.org}"
SLAVENAME="${SLAVENAME:-`hostname -f`}"
RUNDIR=`mktemp -d`
SLAVEKEY="${SLAVEKEY:-}"

function cleanup {
    rm -rf "$RUNDIR"
}

trap cleanup EXIT

cd "$RUNDIR"
wget "$JENKINSURL/jnlpJars/slave.jar"

while true
do
  java \
    -jar slave.jar \
    -jnlpUrl "$JENKINSURL/computer/$SLAVENAME/slave-agent.jnlp" \
    -secret "$SLAVEKEY"
  sleep 30
done
