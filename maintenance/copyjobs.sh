#!/bin/bash
set -e

function usage()
{
  echo "/path/to/script" [33] [34]
}

if [ -z $1 ]
then
  usage
  exit 1
fi

if [ -z $2 ]
then
  usage
  exit 1
fi


oldversion=$1
newversion=$2

cd /var/lib/jenkins/jobs
for oldjob in "M${oldversion}".*
do
    newjob=`echo $oldjob | sed "s/${oldversion}/${newversion}/"`
    echo -n "Copying $oldjob to $newjob"
    mkdir "$newjob"
    echo -n .
    sed "s/${oldversion}/${newversion}/g" "$oldjob"/config.xml > "$newjob"/config.xml
    echo -n .
    echo " done"
done
