#!/bin/bash
########### Variables used ##############
#!# SiteId=behat_whole_suite_m26
#!# BranchId=MOODLE_26_STABLE
#!# DbType=mysqli
#!# DbHost=mysql01.test.in.moodle.com
#!# BehatConfigFile=behat_config_local.php.template
#!# DbUser=moodle
#!# DbPwd=moodle
#!# DbPort=
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

#### Set DbName for oracle ####
if [[ ${DbName} == ${SiteId} && "${DbType}" == "oci" ]]; then
    str=$(hostname)
    echo "Using xe database for oracle"
    DbName=xe
    PhpunitDbPrefix="p${str: -1}"
    BehatDbPrefix="b${str: -1}"
fi

#### Set DbName for mssql ####
if [[ ${DbName} == ${SiteId} && "${DbType}" == "mssql" && "${DbHost}" == "mssql"* ]]; then
    str=$(hostname)
    echo "Using moodle for testing mssql"
    DbName=moodle
    PhpunitDbPrefix="p${str: -2}_"
    BehatDbPrefix="b${str: -2}_"
fi

###############################

# Parent directory, containing code and everything.
homedir=/store
moodledir="${homedir}/moodle"
datadir=/store/moodledata
moodledatadir="${datadir}/data"
faildumpdir="${datadir}/behatfaildump"

# Create this link so it can be accessed by site.
if [ ! -d "${homedir}/workspace/UNIQUESTRING_phpunit_$BranchId_$DbType" ]; then
    mkdir -p ${homedir}/workspace/UNIQUESTRING_phpunit_$BranchId_$DbType
fi

# Start docker
docker run --name my_solr -d -p 8983:8983 -t solr
sleep 10
docker exec -t my_solr bin/solr create_core -c phpunit
sleep 10

# Ensure following directories are there.
mkdir -p $moodledatadir

# Resetting wwwroot and dataroot
rm -rf $moodledatadir/$SiteId
rm -rf $moodledatadir/phpunit_$SiteId

mkdir $moodledatadir/$SiteId
chmod 777 $moodledatadir/$SiteId
mkdir $moodledatadir/phpunit_$SiteId
chmod 777 $moodledatadir/phpunit_$SiteId

# Copying from config template.
replacements="%%DbType%%#${DbType}
%%DbHost%%#${DbHost}
%%SiteId%%#${SiteId}
%%DbUser%%#${DbUser}
%%DbPwd%%#${DbPwd}
%%DbPort%%#${DbPort}
%%DbName%%#${DbName}
%%DataDir%%#${moodledatadir}
%%SiteDbPrefix%%#${SiteDbPrefix}
%%PhpunitDbPrefix%%#${PhpunitDbPrefix}
%%BehatDbPrefix%%#${BehatDbPrefix}"

# Apply template transformations.
text="$( cat $homedir/configs/$BehatConfigFile )"
for i in ${replacements}; do
    text=$( echo "${text}" | sed "s#${i}#g" )
done

# Save the config.php into destination.
echo "${text}" > $moodledir/$SiteId/config.php

cd $moodledir/$SiteId

# Install phpunit via composer.
if [ ! -f "$moodledir/$SiteId/composer.phar" ]; then
    curl -s https://getcomposer.org/installer | php
fi
php composer.phar install --dev --prefer-source

# Install phpunit test environment.
php admin/tool/phpunit/cli/util.php --drop
php admin/tool/phpunit/cli/init.php

# Run phpunit
vendor/bin/phpunit 
exitcode=${PIPESTATUS[0]}

docker stop my_solr
docker rm my_solr
exit $exitcode
