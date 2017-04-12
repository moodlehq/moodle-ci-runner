#!/bin/bash
################################
#!# SiteId=behat_whole_suite_m
OutputFormat=moodle_progress
################################
# Optional Params.
if [ -z "${BehatProfileToUseOnDay}" ]; then
    BehatProfileToUseOnDay="default default default default default default default"
fi
if [ -z "${SELENIUMPORT}" ]; then
    SELENIUMPORT=4445
fi
if [ -z "${PHPPORT}" ]; then
    PHPPORT=8000
fi
if [ -z "${TAGS}" ]; then
    TAGS=""
else
    TAGS="--tags=${TAGS}"
fi

################################

homedir=/store
moodledir="${homedir}/moodle"
datadir=/store/moodledata
moodledatadir="${datadir}/data"

#export DISPLAY=:99
# Start selenium and phpserver
cd $moodledir
$homedir/scripts/selenium.sh start $SELENIUMPORT > /dev/null 2>&1 &
#$homedir/scripts/phpserver.sh start $PHPPORT > /dev/null 2>&1 &
sleep 5
cd -

workspacedir="${SiteId}"
if [ ! -d "${homedir}/workspace/UNIQUESTRING_${workspacedir}" ]; then
    mkdir -p ${homedir}/workspace/UNIQUESTRING_${workspacedir}
    chmod 775 ${homedir}/workspace/UNIQUESTRING_${workspacedir}
fi
if [ ! -d "${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports" ]; then
    mkdir -p ${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports
    chmod 775 ${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports
fi
junitreportspath="${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports/${BUILD_ID}"
echo "JUnit reports path: $junitreportspath"

# Find which profile to use.
dayoftheweek=`date +"%u"`
BehatProfileToUseOnDay=(`echo ${BehatProfileToUseOnDay}`);
behatprofiletouse=${BehatProfileToUseOnDay[ $(( ${dayoftheweek} - 1 )) ]}

# Run tests.
cd $moodledir/$SiteId
echo "CMD: vendor/bin/behat --config $moodledatadir/behat_$SiteId/behat/behat.yml --format $OutputFormat --out --profile $behatprofiletouse --verbose $TAGS"

vendor/bin/behat --config $moodledatadir/behat_$SiteId/behatrun/behat/behat.yml --format $OutputFormat --out std --profile $behatprofiletouse --verbose $TAGS --format junit --out $junitreportspath --suite=default
exitcode=${PIPESTATUS[0]}

# Re-run failed scenarios, to ensure they are true fails.
if [ "${exitcode}" -ne 0 ]; then
    echo "---Running behat again for failed steps---"
    vendor/bin/behat --config $moodledatadir/behat_$SiteId/behatrun/behat/behat.yml --format $OutputFormat --out std --profile $behatprofiletouse --verbose --rerun --suite=default # --out $junitreportspath
    exitcode=${PIPESTATUS[0]}
fi

$homedir/scripts/selenium.sh stop $SELENIUMPORT
#$homedir/scripts/phpserver.sh stop $PHPPORT
exit $exitcode
