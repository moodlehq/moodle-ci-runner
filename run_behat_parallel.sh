#!/bin/bash
################################
#SiteId=behat_whole_suite_m_parallel
OutputFormat=moodle_progress
################################

# Stop service at exist.
function stop_all_instances() {
    for ((i=0;i<${2};i+=1)); do
        echo "Stopping SeleniumServer at port: $((${1}+$i))"
        $homedir/scripts/selenium.sh stop $((${1}+$i))
        sleep 5
    done;
   
}


# Optional Params.
if [ -z "${BehatProfileToUseOnDay}" ]; then
    BehatProfileToUseOnDay="default default default default default default default"
fi
if [ -z "${SELENIUMPORT}" ]; then
    SELENIUMPORT=5555
fi
if [ -z "${PARALLELPROCESS}" ]; then
    PARALLELPROCESS=3
fi
if [ -z "${PHPPORT}" ]; then
    PHPPORT=8000
fi
if [ -z "${PHAHNTOMJSPORT}" ]; then
    PHPPORT=4443
fi

################################

homedir=/store
moodledir="${homedir}/moodle"
datadir=/store/moodledata
moodledatadir="${datadir}/data"

cd $moodledir
# Remove Old logs
$homedir/scripts/delete_old_logs.sh

# Start phpserver and selenium instance
for ((i=0;i<$PARALLELPROCESS;i+=1)); do
  echo "Starting SeleniumServer at port: $(($SELENIUMPORT+$i))"
  $homedir/scripts/selenium.sh start $(($SELENIUMPORT+$i)) > /dev/null 2>&1 &
  sleep 10
done;

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

#junitreportspath="${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports/${BUILD_ID}"
#echo "JUnit reports path: $junitreportspath"

# Find which profile to use.
dayoftheweek=`date +"%u"`
BehatProfileToUseOnDay=(`echo ${BehatProfileToUseOnDay}`);
behatprofiletouse=${BehatProfileToUseOnDay[ $(( ${dayoftheweek} - 1 )) ]}

trap "stop_all_instances $SELENIUMPORT $PARALLELPROCESS" HUP INT QUIT TERM EXIT

# Run tests.
cd $moodledir/$SiteId
echo "Chaning diri $moodledir/$SiteId"

if [ -n "${SUITE_NAME}" ]; then
    php admin/tool/behat/cli/run.php --format="$OutputFormat" --out=std --profile=${behatprofiletouse} --auto-rerun=2 --suite=${SUITE_NAME}
else
    php admin/tool/behat/cli/run.php --format="$OutputFormat" --out=std --profile=${behatprofiletouse} --auto-rerun=2
fi

exitcode=${PIPESTATUS[0]}

echo "\nExit code is ${exitcode} ...... Going to try rerun\n"

#stop_all_instances $SELENIUMPORT $PARALLELPROCESS

exit $exitcode
