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

# If db is oci or mssql then use old version.
if [ "$DBTYPE" == "mssql" ] || [ "$DBTYPE" == "oci" ]; then
  if [ "$PHP_SERVER_DOCKER" == "rajeshtaneja/php:7.0" ]; then
    #PHP_SERVER_DOCKER='rajeshtaneja/php:5.4.45'
    PHP_SERVER_DOCKER='rajeshtaneja/php:5.6'
  fi
fi

# Create a mapping of moodle directory if not available
if [ "$TEST_TO_RUN" == "behat" ]; then
    RUN_DIR_MAP="${MOODLE_PATH}${TEST_TO_RUN}_${MOODLE_BRANCH}_${PROFILE}_${RUN}"
else
    RUN_DIR_MAP="${MOODLE_PATH}${TEST_TO_RUN}_${MOODLE_BRANCH}_${DBTYPE}"
fi

#if [ ! -d "$RUN_DIR_MAP" ]; then
#    echo "Creating the Overlay directory for Run $RUN at $RUN_DIR_MAP"
#    mkdir -p $RUN_DIR_MAP
#    chmod 777 $RUN_DIR_MAP
#    sudo mount -t aufs -o br=${RUN_DIR_MAP}=rw:${MOODLE_PATH}=ro none ${RUN_DIR_MAP}
#fi

# Start moodle test.
NAME_OF_DOCKER_CONTAINER=`echo "$RUN_DIR_MAP" | sed 's,/,_,g' | sed 's/_//1'`

whereami="${PWD}"
cd $MOODLE_PATH

if [ ! -f "$MOODLE_PATH/composer.phar" ]; then
    curl -s https://getcomposer.org/installer | php
fi

php composer.phar install --prefer-dist --no-interaction
cd $whereami

if [ "$TEST_TO_RUN" == "behat" ]; then
    if [ "$PROFILE" == "chrome" ]; then
        SHMMAP="-v /dev/shm:/dev/shm"
    else
        SHMMAP=''
    fi

    # Start phantomjs instance.
    if [[ $SELENIUM_DOCKER == *"rajeshtaneja"* ]]; then
        DOCKER_SELENIUM_INSTANCE=$(docker run -d $SHMMAP -v ${MOODLE_PATH}/:/var/www/html/moodle --entrypoint /init.sh $SELENIUM_DOCKER $PROFILE)
    else
        DOCKER_SELENIUM_INSTANCE=$(docker run -d $SHMMAP -v ${MOODLE_PATH}/:/var/www/html/moodle $SELENIUM_DOCKER)
    fi

    LINK_SELENIUM="--link ${DOCKER_SELENIUM_INSTANCE}:SELENIUM_DOCKER"

    # Wait for 5 seconds before starting behat run.
    sleep 5
    # Get selenium docker instance ip.
    SELENIUMIP=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" $DOCKER_SELENIUM_INSTANCE)
    if [ "$PROFILE" == "phantomjs" ]; then
        SELENIUMURL="--phantomjsurl=${SELENIUMIP}:4443"
    else
        SELENIUMURL="--seleniumurl=${SELENIUMIP}:4444"
    fi

    # Start moodle test.
    NAME_OF_DOCKER_CONTAINER=$(echo "$RUN_DIR_MAP" | sed 's,/,_,g' | sed 's/_//1')
    cmd="docker run -i --rm --user=rajesh --name ${NAME_OF_DOCKER_CONTAINER} -v ${MOODLE_PATH}:${DOCKER_MOODLE_PATH} -v ${MAP_FAILDUMP}:/shared ${LINK_SELENIUM} --entrypoint /behat ${PHP_SERVER_DOCKER} --dbtype=${DBTYPE} --dbhost=${DBHOST} --dbname=${DBNAME} --behatdbprefix=${DBPREFIX} --dbuser=${DBUSER} --dbpass=${DBPASS} --profile=${PROFILE} --process=${RUN} --processes=${TOTAL_RUNS} $SELENIUMURL $EXTRA_OPT $DBPORT --forcedrop"
    #echo $cmd
    docker run \
      -i \
      --rm \
      --user=jenkins \
      --name ${NAME_OF_DOCKER_CONTAINER} \
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
    sudo rm -r ${MAP_FAILDUMP}/moodledata/${MOODLE_BRANCH}/${DBTYPE}/*
    cd $whereami
else
    docker run \
      -i \
      --rm \
      --user=jenkins \
      --name ${NAME_OF_DOCKER_CONTAINER} \
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
        docker stop $DOCKER_SELENIUM_INSTANCE
        docker rm -f $DOCKER_SELENIUM_INSTANCE
    fi
}

trap finish EXIT


exit $EXITCODE
