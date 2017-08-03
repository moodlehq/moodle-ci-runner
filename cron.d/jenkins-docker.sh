#!/bin/bash

PATH=$PATH:/store/scripts

dockercleaner.sh > /var/lib/jenkins/logs/dockercleaner.sh
sleep 2 && dockerdb.sh pgsql > /var/lib/jenkins/logs/dockerdb-pgsql.log 2>&1
sleep 2 && dockerdb.sh mariadb > /var/lib/jenkins/logs/dockerdb-mariadb.log 2>&1
sleep 2 && dockerdb.sh mysql > /var/lib/jenkins/logs/dockerdb-mysql.log 2>&1
sleep 2 && dockerdb.sh sqlsrv > /var/lib/jenkins/logs/dockerdb-sqlsrv.log 2>&1
sleep 2 && dockerdb.sh oracle > /var/lib/jenkins/logs/dockerdb-oracle.log 2>&1
