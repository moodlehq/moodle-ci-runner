#!/bin/bash
########### Variables used ##############
## SiteId=behat_whole_suite_m26
## BranchId=MOODLE_26_STABLE
## dbtorun="mysql pgsql mysql pgsql mssql mysql oracle"
## mysql="DbType:mysqli DbUser:moodle DbPwd:moodle DbHost:mysql01.test.in.moodle.com"
## mariadb="DbType:mariadb DbUser:moodle DbPwd:moodle bHost:mariadb01.test.in.moodle.com"
## pgsql="DbType:pgsql DbUser:postgres DbPwd:moodle DbHost:172.21.0.70"
## oracle="DbType:oci DbUser:system DbPwd:moodle DbHost:oracle01.test.in.moodle.com:1521/xe"
## mssql="DbType:mssql DbUser:sa DbPwd:moodle DbHost:mssql01.test.in.moodle.com"
#########################################
# Optional Params.
if [ -z ${DbName} ]; then
    DbName=${SiteId}
fi
if [ -z ${SiteDbPrefix} ]; then
    SiteDbPrefix=mdl_
fi
if [ -z ${PhpunitDbPrefix} ]; then
    PhpunitDbPrefix=phpunit_
fi
if [ -z ${BehatDbPrefix} ]; then
    BehatDbPrefix=behat_
fi
###########################################
dbtorun=(`echo ${dbtorun}`);
mysql=(`echo ${mysql}`);
mariadb=(`echo ${mariadb}`);
pgsql=(`echo ${pgsql}`);
oracle=(`echo ${oracle}`);
mssql=(`echo ${mssql}`);

# Find which db to run today.
dayoftheweek=`date +"%u"`
dbtouse=${dbtorun[ $(( ${dayoftheweek} - 1 )) ]}
DbPwd
#### Set DbName for oracle ####
if [[ ${DbName} == ${SiteId} && "${dbtouse}" == "oracle" ]]; then
    str=$(hostname)
    echo "Using xe database for oracle"
    DbName=xe
    PhpunitDbPrefix="p${str: -1}"
    BehatDbPrefix="b${str: -1}"
fi

#### Set DbName for mssql ####
if [[ ${DbName} == ${SiteId} && "${dbtouse}" == "mssql" ]]; then
    str=$(hostname)
    echo "Using moodle for testing mssql"
    DbName=moodle
    PhpunitDbPrefix="p${str: -2}_"
    BehatDbPrefix="b${str: -2}_"
fi

###############################
eval dbtousedetails="(\"\${$dbtouse[@]}\")"
# Set all values.
for dbtouse in ${dbtousedetails[@]} ; do
    KEY=${dbtouse%%:*}
    VALUE=${dbtouse#*:}
    eval ${KEY}=${VALUE}
done

# Create this link so it can be accessed by site.
if [ ! -d "${homedir}/workspace/UNIQUESTRING_phpunit_$SiteId" ]; then
    mkdir -p ${homedir}/workspace/UNIQUESTRING_phpunit_$SiteId
fi

docker run --rm moodle/php5.4.45:master /scripts/phpunit.sh --dbtype=${DbType} --dbhost=${DbHost} --dbname=${DbName} --branch=${BranchId} --phpunitdbprefix=${PhpunitDbPrefix} --dbuser=${DbUser} --dbpass=${DbPwd}
