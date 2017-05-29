#!/bin/bash
########### Variables used ##############
# git=git://git.moodle.org/integration.git
# branch=master

# dbtorun="mariadb pgsql mysql pgsql mssql mysql oracle"

# mysql="dbtype:mysqli dbuser:moodle dbpass:moodle dbhost:mysql01.test.in.moodle.com dbprefix:mdl_ dbname:moodle"

# mariadb="dbtype:mariadb dbuser:moodle dbpass:moodle dbhost:mariadb01.test.in.moodle.com dbperfix:mdl_ dbname:moodle"

# pgsql="dbtype:pgsql dbuser:moodle dbpass:moodle dbhost:localhost"

# oracle="dbtype:oci dbuser:system dbpass:moodle dbhost:oracle01.test.in.moodle.com:1521/xe dbperfix:m_ dbname:xe"

# mssql="dbtype:mssql dbuser:sa dbpass:moodle dbhost:mssql01.test.in.moodle.com dbperfix:m_ dbname:moodle"

# profile=firefox
# process=2/10

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
if [[ -z ${dbtorun} ]]; then
  dbtouse=pgsql
else
  dbtouse=${dbtorun[ $(( ${dayoftheweek} - 1 )) ]}
fi

eval dbtousedetails="(\"\${$dbtouse[@]}\")"

# Set all values.
for dbtouse in ${dbtousedetails[@]} ; do
    KEY=${dbtouse%%:*}
    VALUE=${dbtouse#*:}
    eval ${KEY}=${VALUE}
done

# Variables to pass
if [[ -z ${git} ]]; then
  git="--git=git://git.moodle.org/integration.git"
else
  git="--git=${git}"
fi
command="sudo docker run --rm -v /storefaildump:/shared rajeshtaneja/moodle /behat.sh ${git}" 
if [[ -z ${branch} ]]; then
  branch="--branch=master"
else
  branch="--branch=${branch}"
fi
command="${command} ${branch}" 

if [[ -z ${process} ]]; then
  process="--process=1"
  processes="--processes=1"
else
  run=`echo $process | cut -d '/' -f 1`
  processes=`echo $process | cut -d '/' -f 2`
  process="--process=${run}"
  processes="--processes=${processes}"
fi
command="${command} ${process} ${processes}"

# Add db details
dbtype="--dbtype=${dbtype}"
dbhost="--dbhost=${dbhost}"
if [[ -z ${dbname} ]]; then
  dbname="--dbname=moodle"
else
  dbname="--dbname=${dbname}"
fi
if [[ -z ${dbuser} ]]; then
  dbuser="--dbuser=moodle"
else
  dbuser="--dbuser=${dbuser}"
fi
if [[ -z ${dbpass} ]]; then
  dbpass="--dbpass=moodle"
else
  dbpass="--dbpass=${dbpass}"
fi
if [[ -z ${dbprefix} ]]; then
  dbprefix="--behatdbprefix=b_"
else
  dbprefix="--behatdbprefix=${dbprefix}"
fi
command="${command} ${dbtype} ${dbhost} ${dbname} ${dbuser} ${dbpass} ${behatdbprefix}"

# Profile and output
if [[ -n ${profile} ]]; then
  command="${command} --profile=${profile}"
fi
if [[ -n ${format} ]]; then
  command="${command} --format=${format}"
fi
if [[ -n ${output} ]]; then
  command="${command} --output=${output}"
fi
eval $command



