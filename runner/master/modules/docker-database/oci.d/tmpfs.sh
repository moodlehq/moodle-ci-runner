#!/bin/bash

if [ -d /var/lib/oracle ]
then
  service oracle-xe stop
  mv /u01/app/oracle/oradata/XE /var/lib/oracle/
  rmdir /u01/app/oracle/oradata
  ln -s /var/lib/oracle /u01/app/oracle/oradata

  service oracle-xe start
fi
