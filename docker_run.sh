#!/bin/bash

###################################################
# Script to run behat and unit tests.
###################################################

########### Variables used ##############
#SiteId=behat_whole_suite_m30_phpunit
# Database variables can be ############
#dbtorun="pgsql pgsql pgsql pgsql mssql mysql oracle"
#mysql="dbtype:mysqli dbuser:moodle dbpass:moodle dbhost:172.21.0.3 dbprefix:b_ dbname:behat_whole_suite_m31_parallel"
#mariadb="dbtype:mariadb dbuser:moodle dbpass:moodle dbhost:172.21.0.3:3307 dbperfix:b_ dbname:behat_whole_suite_m31_parallel"
#pgsql="dbtype:pgsql dbuser:moodle dbpass:moodle dbhost:172.20.0.34 dbperfix:ba_ dbname:php7"
#oracle="dbtype:oci dbuser:system dbpass:oracle dbhost:172.21.0.3:1521/xe dbperfix:a dbname:xe"
#mssql="dbtype:mssql dbuser:sa dbpass:moodle dbhost:mssql01.test.in.moodle.com dbperfix:b_ dbname:behat_whole_suite_m31_parallel"
#PROCESS=0/1
#OR
#DBTYPE='pgsql'
#DBHOST='raji.per.in.moodle.com'
#DBUSER='moodle'
#DBPASS='moodle'
#DBNAME='php7'
#DBPREFIX='b_'
#DBPORT=3361
#RUN=0
#TOTAL_RUNS=4

#MOODLE_PATH='/var/www/html/im30/'
##SELENIUM_DOCKER='selenium/standalone-chrome:2.44.0'
##SELENIUM_DOCKER='selenium/standalone-firefox:2.53.0'
#SELENIUM_DOCKER='rajeshtaneja/selenium:2.47.1'
#MAP_FAILDUMP='/home/rajesh/Desktop/faildump'
#PHP_SERVER_DOCKER='rajeshtaneja/php:7.0.4'
#PHP_SERVER_DOCKER='rajeshtaneja/php:5.4'
##PHP_SERVER_DOCKER='rajeshtaneja/php:5.5.9'
##PHP_SERVER_DOCKER='rajeshtaneja/php:5.6.22'

#MOODLE_BRANCH='30'
#TEST_TO_RUN='behat'
#EXTRA_OPT='--tags=@mod_quiz&&@javascript'
#PROFILE='chrome'
#DOCKER_MOODLE_PATH=/var/www/html/moodle
#DOCKER_MOODLE_PATH=/moodle
###################################################
# Optional Params.

# Select db to use today.
if [ -n "$dbtorun" ]; then
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
    echo "Running against ${dbtouse}"

    eval dbtousedetails="(\"\${$dbtouse[@]}\")"

    # Set db values.
    for dbtouse in ${dbtousedetails[@]} ; do
    KEY=${dbtouse%%:*}
    VALUE=${dbtouse#*:}
    eval ${KEY}=${VALUE}
    done

    # Get total runs.
    if [[ -z ${PROCESS} ]]; then
        if [ -z "$RUN" ]; then
            RUN=1
        fi

        if [ -z "$TOTAL_RUN" ]; then
            TOTAL_RUNS=1
        fi
    else
        RUN=`echo $PROCESS | cut -d '/' -f 1`
        TOTAL_RUNS=`echo $PROCESS | cut -d '/' -f 2`
    fi

    # Dbtype and dbhost can't be guessed. enure we have one.
    if [ -z "$dbtype" ] || [ -z "$dbhost" ]; then
        echo "Dbtype or dbhost is not set."
        exit 1
    fi
    DBTYPE=${dbtype}
    DBHOST=${dbhost}
    if [[ -z ${dbname} ]]; then
        DBNAME=${SiteId}
    else
        DBNAME=${dbname}
    fi
    if [[ -z ${dbuser} ]]; then
        DBUSER=moodle
    else
        DBUSER=${dbuser}
    fi
    if [[ -z ${dbpass} ]]; then
        DBPASS=moodle
    else
        DBPASS=${dbpass}
    fi
    if [[ -z ${dbprefix} ]]; then
        if [ "$TEST_TO_RUN" == "phpunit" ]; then
            DBPREFIX=t_
        else
            DBPREFIX=b_
        fi
    else
        DBPREFIX=${dbprefix}
    fi

    if [ -n "$dbport" ]; then
        DBPORT="--dbport=${dbport}"
    else
        DBPORT=''
    fi
else
    if [ -z "$DBNAME" ]; then
        DBNAME=${SiteId}
    fi

    if [ -z "$DBPREFIX" ]; then
        if [ "$TEST_TO_RUN" == "phpunit" ]; then
          DBPREFIX=t_
        else
          DBPREFIX=b_
        fi
    fi
fi

if [ ! -z "$MAP_FAILDUMP" ]
then
  if [ ! -d "$MAP_FAILDUMP" ]
  then
    mkdir -p $MAP_FAILDUMP
    chmod 777 $MAP_FAILDUMP
  fi
fi

# Start moodle test.
UUID=$(uuid | sha1sum | awk '{print $1}')
UUID=${UUID:0:16}

echo "============================================================================"
echo "== Job summary:"
echo "== Container prefix: {$UUID}"
echo "== UUID: {$UUID}"
echo "== DBTYPE: ${DBTYPE}"
echo "== DBHOST: ${DBHOST}"
echo "== DBPORT: ${DBPORT}"
echo "== DBUSER: ${DBUSER}"
echo "== DBPASS: ${DBPASS}"
echo "== DBNAME: ${DBNAME}"
echo "============================================================================"

whereami="${PWD}"
cd $MOODLE_PATH

if [ "$TEST_TO_RUN" == "behat" ]; then
    if [ "$PROFILE" == "chrome" ]; then
        SHMMAP="-v /dev/shm:/dev/shm"
    else
        SHMMAP=''
    fi

    SELNAME="${UUID}_selenium"

    # Start phantomjs instance.
    if [[ $SELENIUM_DOCKER == *"rajeshtaneja"* ]]; then
        docker run \
            --network nightly \
            --name ${SELNAME} \
            -d $SHMMAP \
            -v ${MOODLE_PATH}/:/var/www/html/moodle \
            --entrypoint /init.sh \
            $SELENIUM_DOCKER $PROFILE
    else
        docker run \
            --network nightly \
            --name ${SELNAME} \
            -d $SHMMAP \
            -v ${MOODLE_PATH}/:/var/www/html/moodle \
            --entrypoint /init.sh \
            $SELENIUM_DOCKER
    fi

    # Wait for 5 seconds before starting behat run.
    sleep 5
    if [ "$PROFILE" == "phantomjs" ]; then
        SELENIUMURL="--phantomjsurl=${SELNAME}:4443"
    else
        SELENIUMURL="--seleniumurl=${SELNAME}:4444"
    fi

    # Start moodle test.
    docker run \
      --network nightly \
      -i \
      --rm \
      --user=$UID \
      --name ${UUID}_run \
      -v /var/lib/jenkins/.composer:/home/rajesh/.composer:rw \
      -v ${MOODLE_PATH}:${DOCKER_MOODLE_PATH} \
      -v ${MAP_FAILDUMP}:/shared ${LINK_SELENIUM} \
      --entrypoint /behat ${PHP_SERVER_DOCKER} \
      --dbtype=${DBTYPE} \
      --dbhost=${DBHOST} \
      --dbname=${DBNAME} \
      --behatdbprefix=${DBPREFIX} \
      --dbuser=${DBUSER} \
      --dbpass=${DBPASS} \
      --profile=${PROFILE} \
      --run=${RUN} \
      --totalruns=${TOTAL_RUNS} \
      $SELENIUMURL \
      $EXTRA_OPT \
      $DBPORT \
      --forcedrop
    EXITCODE=$?
    # Remove used directory.
    sudo rm -rf ${MAP_FAILDUMP}/moodledata/${MOODLE_BRANCH}/${DBTYPE}/* > /dev/null 2>&1
    cd $whereami
else
    docker run \
      --network nightly \
      -i \
      --rm \
      --user=$UID \
      --name ${UUID}_run \
      -v /var/lib/jenkins/.composer:/home/rajesh/.composer:rw \
      -v ${MOODLE_PATH}:${DOCKER_MOODLE_PATH} ${LINK_SELENIUM} \
      --entrypoint /phpunit ${PHP_SERVER_DOCKER} \
      --dbtype=${DBTYPE} \
      --dbhost=${DBHOST} \
      --dbname=${DBNAME} \
      --phpunitdbprefix=${DBPREFIX} \
      --dbuser=${DBUSER} \
      --dbpass=${DBPASS} $EXTRA_OPT \
      --dbport=${DBPORT} \
      --forcedrop
    EXITCODE=$?
fi

# Cleanup all the docker images here.
function finish {
    if [ -n "$LINK_SELENIUM" ]; then
        echo "Stopping docker images..."
        docker stop $SELNAME
        docker rm -f $SELNAME
    fi
}

trap finish EXIT


exit $EXITCODE
