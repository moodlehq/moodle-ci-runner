#!/bin/bash
########### Variables used ##############
#!#SiteId=behat_whole_suite_m
#!#BranchId=master
#!#BehatConfigFile=behat_config_local.php.template
#!#DbName=${SiteId}
#!#
#!#dbtorun="mysql mssql mariadb pgsql mysql mssql mariadb"
#!#
#!#mysql="DbType:mysqli DbUser:moodle DbPwd:moodle DbHost:localhost"
#!#
#!#mariadb="DbType:mariadb DbUser:moodle DbPwd:moodle bHost:mariadb01.test.in.moodle.com"
#!#
#!#pgsql="DbType:pgsql DbUser:moodle DbPwd:moodle DbHost:localhost"
#!#
#!#oracle="DbType:oci DbUser:system DbPwd:moodle DbHost:oracle01.test.in.moodle.com:1521/xe"
#!#
#!#mssql="DbType:mssql DbUser:sa DbPwd:moodle DbHost:mssql01.test.in.moodle.com"
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
if [ -z "${SELENIUMPORT}" ]; then
    SELENIUMPORT=4445
fi
if [ -z "${PARALLELPROCESS}" ]; then
    PARALLELPROCESS=1
fi
if [ -z "${PHPPORT}" ]; then
    PHPPORT=8000
fi
##########################################

# Change string to array.
dbtorun=(`echo ${dbtorun}`);
mysql=(`echo ${mysql}`);
mariadb=(`echo ${mariadb}`);
pgsql=(`echo ${pgsql}`);
oracle=(`echo ${oracle}`);
mssql=(`echo ${mssql}`);

# Find which db to run today.
dayoftheweek=`date +"%u"`
dbtouse=${dbtorun[ $(( ${dayoftheweek} - 1 )) ]}

#### Set DbName for oracle ####
if [[ ${DbName} == ${SiteId} && "${dbtouse}" == "oracle" ]]; then
    str=$(hostname)
    echo "Using xe database for oracle"
    DbName=xe
    PhpunitDbPrefix="p${str: -1}"
    BehatDbPrefix="b${str: -1}"
fi

###############################

eval dbtousedetails="(\"\${$dbtouse[@]}\")"

# Set all values.
for dbtouse in ${dbtousedetails[@]} ; do
    KEY=${dbtouse%%:*}
    VALUE=${dbtouse#*:}
    eval ${KEY}=${VALUE}
done

# Parent directory, containing code and everything.
homedir=/store
moodledir="${homedir}/moodle"
datadir=/store/moodledata
moodledatadir="${datadir}/data"
faildumpdir="${datadir}/behatfaildump"

# Create this link so it can be accessed by site.
if [ ! -d "${homedir}/workspace/UNIQUESTRING_behat" ]; then
    mkdir -p ${homedir}/workspace/UNIQUESTRING_behat
fi

if [ ! -d "${homedir}/workspace/UNIQUESTRING_behat_$BranchId" ]; then
    mkdir -p ${homedir}/workspace/UNIQUESTRING_behat_$BranchId
fi
if [ ! -L "/var/www/html/screenshots_$SiteId" ]; then
    ln -s $faildumpdir /var/www/screenshots_$SiteId
fi

# Ensure following directories are there.
mkdir -p $moodledatadir

# Resetting wwwroot and dataroot
rm -rf $moodledatadir/$SiteId
rm -rf $moodledatadir/behat_$SiteId

mkdir $moodledatadir/$SiteId
chmod 777 $moodledatadir/$SiteId
mkdir $moodledatadir/behat_$SiteId
chmod 777 $moodledatadir/behat_$SiteId

# Create screenshot directory if not present.
mkdir -p $faildumpdir/$SiteId
chmod 777 $faildumpdir/$SiteId


# Copying from config template.
replacements="%%DbType%%#${DbType}
%%DbHost%%#${DbHost}
%%SiteId%%#${SiteId}
%%DbUser%%#${DbUser}
%%DbPwd%%#${DbPwd}
%%DbName%%#${DbName}
%%DataDir%%#${moodledatadir}
%%FailDumpDir%%#${faildumpdir}
%%SiteDbPrefix%%#${SiteDbPrefix}
%%PhpunitDbPrefix%%#${PhpunitDbPrefix}
%%BehatDbPrefix%%#${BehatDbPrefix}
%%PhpPort%%#${PHPPORT}
%%SeleniumPort%%#${SELENIUMPORT}"

# Apply template transformations.
text="$( cat $homedir/configs/$BehatConfigFile )"
for i in ${replacements}; do
    text=$( echo "${text}" | sed "s#${i}#g" )
done

# Save the config.php into destination.
echo "${text}" > $moodledir/$SiteId/config.php

cd $moodledir/$SiteId

# Install behat dependencies.
if [ ! -f "$moodledir/$SiteId/composer.phar" ]; then
    curl -s https://getcomposer.org/installer | php
fi
php composer.phar install --prefer-source

# Install behat test environment.
php admin/tool/behat/cli/util.php --drop
php admin/tool/behat/cli/init.php
