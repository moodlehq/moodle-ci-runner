#!/bin/bash
################################
SiteId=behat_whole_suite_m_parallel
OutputFormat=moodle_progress,junit
################################
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
rerunfile="$moodledatadir/$SiteId-rerunlist"

#export DISPLAY=:99

cd $moodledir
# Remove Old logs
$homedir/scripts/delete_old_logs.sh

# Start phpserver and selenium instance
DOCKER=()
for ((i=0;i<$PARALLELPROCESS;i+=1)); do
    echo "Starting SeleniumServer at port: $(($SELENIUMPORT+$i))"
    $homedir/scripts/selenium.sh start $(($SELENIUMPORT+$i)) > /dev/null 2>&1 &
    #docid=`sudo docker run -d -p $(($SELENIUMPORT+$i)):$(($SELENIUMPORT+$i)) selenium/standalone-firefox:2.45.0`
    #DOCKER+=($docid)  
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
for ((i=1;i<=$PARALLELPROCESS;i+=1)); do
    if [ -e "${rerunfile}${i}.txt" ]; then
        rm $rerunfile$i.txt
    fi
done;

junitreportspath="${homedir}/workspace/UNIQUESTRING_${workspacedir}/junit_reports/${BUILD_ID}"
echo "JUnit reports path: $junitreportspath"

# Find which profile to use.
dayoftheweek=`date +"%u"`
BehatProfileToUseOnDay=(`echo ${BehatProfileToUseOnDay}`);
behatprofiletouse=${BehatProfileToUseOnDay[ $(( ${dayoftheweek} - 1 )) ]}

# Run tests.
cd $moodledir/$SiteId
echo "Chaning diri $moodledir/$SiteId"
php admin/tool/behat/cli/run.php --format="$OutputFormat" --out=",$junitreportspath" --rerun="$rerunfile{runprocess}.txt" --replace="{runprocess}"
exitcode=${PIPESTATUS[0]}

# Re-run failed scenarios, to ensure they are true fails.
if [ "${exitcode}" -ne 0 ]; then
    exitcode=0
    for ((i=1;i<=$PARALLELPROCESS;i+=1)); do
    	thisrerunfile="$rerunfile$i.txt"
    	if [ -e "${thisrerunfile}" ]; then
        	if [ -s "${thisrerunfile}" ]; then
	    		echo "---Running behat again for failed steps---"
			if [ ! -L $moodledir/$SiteId/behatrun$i ]; then
                            ln -s $moodledir/$SiteId $moodledir/$SiteId/behatrun$i
                        fi
			sleep 5
    		        vendor/bin/behat --config $moodledatadir/behat_$SiteId$i/behat/behat.yml --format $OutputFormat --out ','$junitreportspath --profile $behatprofiletouse --verbose --rerun $thisrerunfile
		        exitcode=$(($exitcode+${PIPESTATUS[0]}))
	        fi
        	rm $thisrerunfile
    	fi
    done;
fi
for ((i=0;i<$PARALLELPROCESS;i+=1)); do
    echo "Stopping SeleniumServer at port: $(($SELENIUMPORT+$i))"
    $homedir/scripts/selenium.sh stop $(($SELENIUMPORT+$i))
    #for i in "${array[@]}"
    #do
#	sudo docker kill $i
#    sleep 2
#    done
done;
exit $exitcode
