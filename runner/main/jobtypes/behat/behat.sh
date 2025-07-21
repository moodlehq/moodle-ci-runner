#!/usr/bin/env bash
#
# This file is part of the Moodle Continuous Integration Project.
#
# Moodle is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Moodle is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Moodle.  If not, see <https://www.gnu.org/licenses/>.

# Behat job type functions.

# Behat needed variables to go to the env file.
function behat_to_env_file() {
    local env=(
        DBTYPE
        DBTAG
        DBHOST
        DBNAME
        DBUSER
        DBPASS
        DBCOLLATION
        DBREPLICAS
        DBHOST_DBREPLICA

        BBBMOCKURL
        MATRIXMOCKURL

        SELENIUMURL_1
        SELENIUMURL_2
        SELENIUMURL_3
        SELENIUMURL_4
        SELENIUMURL_5
        SELENIUMURL_6
        SELENIUMURL_7
        SELENIUMURL_8
        SELENIUMURL_9
        SELENIUMURL_10

        WEBSERVER
        APACHE_DOCUMENT_ROOT
        PUBLICROOT

        IONICURL

        BROWSER
        BROWSER_DEBUG
        BROWSER_HEADLESS
        BROWSER_CHROME_ARGS
        BROWSER_FIREFOX_ARGS
        BEHAT_PARALLEL

        BEHAT_TIMING_FILENAME
        BEHAT_INCREASE_TIMEOUT
        BEHAT_INIT_ARGS

        MLBACKENDTESTNAME

        MOODLE_CONFIG
    )
    echo "${env[@]}"
}

# Behat information to be added to the summary.
function behat_to_summary() {
    echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
    echo "== PHP version: ${PHP_VERSION}"
    echo "== DBTYPE: ${DBTYPE}"
    echo "== DBTAG: ${DBTAG}"
    echo "== DBREPLICAS: ${DBREPLICAS}"
    echo "== MLBACKEND_PYTHON_VERSION: ${MLBACKEND_PYTHON_VERSION}"
    echo "== RUNCOUNT: ${RUNCOUNT}"
    echo "== BROWSER: ${BROWSER}"
    echo "== BROWSER_DEBUG: ${BROWSER_DEBUG}"
    echo "== BROWSER_HEADLESS: ${BROWSER_HEADLESS}"
    echo "== BROWSER_CHROME_ARGS: ${BROWSER_CHROME_ARGS}"
    echo "== BROWSER_FIREFOX_ARGS: ${BROWSER_FIREFOX_ARGS}"
    echo "== BEHAT_SUITE: ${BEHAT_SUITE}"
    echo "== BEHAT_TAGS: ${BEHAT_TAGS}"
    echo "== BEHAT_NAME: ${BEHAT_NAME}"
    echo "== BEHAT_PARALLEL: ${BEHAT_PARALLEL}"
    echo "== BEHAT_RERUNS: ${BEHAT_RERUNS}"
    echo "== BEHAT_TIMING_FILENAME: ${BEHAT_TIMING_FILENAME}"
    echo "== BEHAT_INCREASE_TIMEOUT: ${BEHAT_INCREASE_TIMEOUT}"
    echo "== BEHAT_INIT_ARGS: ${BEHAT_INIT_ARGS}"
    echo "== MOODLE_CONFIG: ${MOODLE_CONFIG}"
    if [[ -n "${GOOD_COMMIT}" ]] || [[ -n "${BAD_COMMIT}" ]]; then
        echo "== GOOD_COMMIT: ${GOOD_COMMIT}"
        echo "== BAD_COMMIT: ${BAD_COMMIT}"
    fi
    echo "== MOBILE_VERSION: ${MOBILE_VERSION}"
    echo "== MOBILE_APP_PORT: ${MOBILE_APP_PORT}"
    echo "== PLUGINSTOINSTALL: ${PLUGINSTOINSTALL}"
}

# This job type defines the following env variables
function behat_env() {
    env=(
        RUNCOUNT
        BEHAT_SUITE
        BEHAT_TAGS
        BEHAT_NAME
        BEHAT_PARALLEL
        BEHAT_RERUNS
        BEHAT_TIMING_FILENAME
        BEHAT_INCREASE_TIMEOUT
        BEHAT_INIT_ARGS
        EXITCODE
    )
    echo "${env[@]}"
}

# Behat needed modules. Note that the order is important.
function behat_modules() {
    local modules=(
        env
        summary
        docker
        docker-logs
        git
        browser
        plugins
        docker-database
        docker-mocks
        docker-selenium
        docker-ionic
        docker-mlbackend
        docker-php
        moodle-config
        moodle-flaky-tests
        moodle-core-copy
        docker-healthy
        docker-summary
    )
    echo "${modules[@]}"
}

# Behat job type checks.
function behat_check() {
    # Check all module dependencies.
    verify_modules $(behat_modules)

    # These env variables must be set for the job to work.
    verify_env UUID WORKSPACE SHAREDDIR ENVIROPATH WEBSERVER GOOD_COMMIT BAD_COMMIT
}

# Behat job type init.
function behat_config() {
    # Apply some defaults.
    PUBLICROOT="${PUBLICROOT:-}"
    RUNCOUNT="${RUNCOUNT:-1}"
    BEHAT_SUITE="${BEHAT_SUITE:-}"
    BEHAT_TAGS="${BEHAT_TAGS:-}"
    BEHAT_NAME="${BEHAT_NAME:-}"
    BEHAT_PARALLEL="${BEHAT_PARALLEL:-3}"
    BEHAT_RERUNS="${BEHAT_RERUNS:-1}"
    BEHAT_INCREASE_TIMEOUT="${BEHAT_INCREASE_TIMEOUT:-}"
    BEHAT_TIMING_FILENAME="${BEHAT_TIMING_FILENAME:-}"
    BEHAT_INIT_ARGS="${BEHAT_INIT_ARGS:-}"
    EXITCODE=0

    # If the --name option is going to be used, then disable any parallel execution, it's not worth
    # instantiating N sites for just running one feature/scenario.
    if [[ -n "${BEHAT_NAME}" ]] && [[ "${BEHAT_PARALLEL}" -gt 1 ]]; then
        print_warning "parallel option disabled because of BEHAT_NAME (--name) behat option being used."
        BEHAT_PARALLEL=1
    fi

    # If, for any reason, BEHAT_PARALLEL is not a number or it's 0, we set it to 1.
    if [[ ! ${BEHAT_PARALLEL} =~ ^[0-9]+$ ]] || [[ ${BEHAT_PARALLEL} -eq 0 ]]; then
        print_warning "BEHAT_PARALLEL is not a number or it's 0, setting it to 1."
        BEHAT_PARALLEL=1
    fi

    # If GOOD_COMMIT and BAD_COMMIT are set, it means that we are going to run a bisect
    # session, so we need to enable FULLGIT (to get access to complete repository clone).
    if [[ -n "${GOOD_COMMIT}" ]] && [[ -n "${BAD_COMMIT}" ]]; then
        FULLGIT="yes"
        # Also, we don't want to allow repetitions, parallels, reruns or timing in the bisect session.
        RUNCOUNT=1
        BEHAT_PARALLEL=1
        BEHAT_RERUNS=0
        BEHAT_TIMING_FILENAME=
    fi
}

# Behat job type setup.
function behat_setup() {
    # If both GOOD_COMMIT and BAD_COMMIT are not set, we are going to run a normal session.
    # (for bisect sessions we don't have to setup the environment).
    if [[ -z "${GOOD_COMMIT}" ]] && [[ -z "${BAD_COMMIT}" ]]; then
        behat_setup_normal
    fi
}

# Behat job type setup for normal mode.
function behat_setup_normal() {
    # If there is a timing filename configured, look for it within the workspace/timing folder.
    # And copy it to the shared folder that the docker-php container will use.
    if [[ -n "${BEHAT_TIMING_FILENAME}" ]]; then
        mkdir -p "${WORKSPACE}/timing"
        local timingpath="${WORKSPACE}/timing/${BEHAT_TIMING_FILENAME}"
        if [[ -f "${timingpath}" ]]; then
            # Copy the timing file to the shared folder.
            cp "${timingpath}" "${SHAREDDIR}"/timing.json
        else
            # Create an empty timing file.
            touch "${SHAREDDIR}"/timing.json
        fi
    fi

    # Init the Behat site.
    echo
    echo ">>> startsection Initialising Behat environment at $(date)<<<"
    echo "============================================================================"
    local initcmd
    behat_initcmd initcmd # By nameref.

    echo "Running: ${initcmd[*]}"

    docker exec -t -u www-data "${WEBSERVER}" "${initcmd[@]}"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Returns (by nameref) an array with the command needed to init the Behat site.
function behat_initcmd() {
    local -n cmd=$1
    # We need to determine the init suite to use.
    local initsuite=""
    if [[ -n "$BEHAT_SUITE" ]]; then
        initsuite="-a=${BEHAT_SUITE}"
    fi

    # Build the complete init command.
    cmd=(
        php ${PUBLICROOT}admin/tool/behat/cli/init.php
        "${initsuite}"
        -j="${BEHAT_PARALLEL}"
        --axe
    )
    if [[ -n "${BEHAT_INIT_ARGS}" ]]; then
        cmd+=( "${BEHAT_INIT_ARGS}")
    fi
}

# Behat job type run.
function behat_run() {
    # If both GOOD_COMMIT and BAD_COMMIT are not set, we are going to run a normal session.
    if [[ -z "${GOOD_COMMIT}" ]] && [[ -z "${BAD_COMMIT}" ]]; then
        behat_run_normal
    else
        # If GOOD_COMMIT and BAD_COMMIT are set, we are going to run a bisect session.
        behat_run_bisect
    fi
}

# PHPUnit job tye run for normal mode.
function behat_run_normal() {    # Run the job type.
    echo
    if [[ RUNCOUNT -gt 1 ]]; then
        echo ">>> startsection Starting ${RUNCOUNT} Behat main runs at $(date) <<<"
    else
        echo ">>> startsection Starting Behat main run at $(date) <<<"
    fi
    echo "============================================================================"

    # Calculate the command to run. The function will return the command in the passed array.
    local cmd=
    behat_main_command cmd

    echo "Running: ${cmd[*]}"

    # Run the command "RUNCOUNT" times.
    local iter=1
    while [[ ${iter} -le ${RUNCOUNT} ]]; do
        echo
        echo ">>> Behat run ${iter} at $(date) <<<"
        docker exec -t -u www-data "${WEBSERVER}" "${cmd[@]}"
        EXITCODE=$((EXITCODE + $?))
        iter=$((iter+1))
    done

    echo "============================================================================"
    echo "== Date: $(date)"
    echo "== Main run exit code: ${EXITCODE}"
    echo "============================================================================"
    echo ">>> stopsection <<<"

    # If the main run passed, we are done.
    if [[ "${EXITCODE}" -eq 0 ]]; then
        return
    fi

    # Time to start managing the reruns.
    # Only if reruns were requested, obviously.
    if [[ "${BEHAT_RERUNS}" -eq 0 ]]; then
        return
    fi

    # We have reruns to perform, let's do them. Note that
    # all the reruns are, always, run 1 by 1, no matter if
    # the main run was single or parallel.

    # This is a double nested loop, the outer one is for the reruns
    # and the inner one is for the parallel runs.
    local rerun=
    local process=

    for rerun in $(seq 1 "${BEHAT_RERUNS}"); do
        for process in $(seq 1 "${BEHAT_PARALLEL}"); do
            local processmask=$((1 << process-1))
            # Check if the previous build (main or rerun) of this (parallel) process failed.
            if [[ $((EXITCODE & processmask)) -eq 0 ]]; then
                # The previous build passed, no need to rerun it.
                continue
            fi

            # Arrived here, we are going to rerun this process, because previous execution failed.
            echo
            echo ">>> startsection Starting Behat rerun ${rerun} of process ${process} at $(date) <<<"
            echo "============================================================================"

            # Reset the exit code for this process.
            EXITCODE=$((EXITCODE - processmask))

            # Calculate the command to run. The function will return the command in the passed array.
            local reruncmd=
            behat_rerun_command reruncmd "${rerun}" "${process}"
            echo "Running: ${reruncmd[*]}"

            # And run it.
            if ! docker exec -t -u www-data -e WINDOWSCALE=1.5 "${WEBSERVER}" "${reruncmd[@]}"; then
                # Rerun failed, let's feed the exit code again.
                EXITCODE=$((EXITCODE + processmask))
            fi

            echo "============================================================================"
            echo "== Date: $(date)"
            echo "== Rerun ${rerun} of process ${process} exit code: ${EXITCODE}"
            echo "============================================================================"
            echo ">>> stopsection <<<"
        done
    done
}

# Behat job tye run for bisect mode.
function behat_run_bisect() {
    # Run the job type.
    echo
    echo ">>> startsection Starting Behat bisect session at $(date) <<<"
    echo "=== Good commit: ${GOOD_COMMIT}"
    echo "=== Bad commit: ${BAD_COMMIT}"
    echo "============================================================================"
    # Start the bisect session.
    docker exec -t -u www-data "${WEBSERVER}" \
        git bisect start "${BAD_COMMIT}" "${GOOD_COMMIT}"

    # Build the int command.
    local initcmd
    behat_initcmd initcmd # By nameref.

    # Build the run command.
    local runcmd
    behat_main_command runcmd # By nameref.

    # Prepare the commands to be injected into shell script (not needed for direct execution, only when injecting).
    # (any element having spaces/ampersands needs to be explicitly quoted, --tags and --name are the usual suspects).
    for i in "${!runcmd[@]}"; do
        # Only if the element is an name=value option.
        if [[ ${runcmd[$i]} == --*=* ]]; then
            # Split the option in name and value.
            local name="${runcmd[$i]%%=*}"
            local value="${runcmd[$i]#*=}"
            # If the value has spaces, quote it.
            if [[ ${value} == *" "* ]]; then
                runcmd[$i]="${name}=\"${value}\""
            fi
            # If the value has ampersand, quote it.
            if [[ ${value} == *"&"* ]]; then
                runcmd[$i]="${name}=\"${value}\""
            fi
        fi
    done

    # Generate the bisect.sh script that we are going to use to run the behat bisect session.
    # (it runs both init and run commands together).
    docker exec -i -u www-data "${WEBSERVER}" \
        bash -c "cat > bisect.sh" <<- EOF
			#!/bin/bash
			${initcmd[@]} >/dev/null 2>&1; ${runcmd[@]}
			exitcode=\$?
			echo "============================================================================"
			exit \$exitcode
			EOF

    # Run the bisect session.
    echo "============================================================================"
    docker exec -u www-data "${WEBSERVER}" \
        git bisect run bash bisect.sh
    EXITCODE=$?

    # Print the bisect logs, for the records.
    echo
    echo "============================================================================"
    echo "Bisect logs and reset:"
    docker exec -u www-data "${WEBSERVER}" \
        git bisect log

    # Finish the bisect session.
    docker exec -u www-data "${WEBSERVER}" \
        git bisect reset

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Behat job type teardown.
function behat_teardown() {
    # Need to copy the updated timing file back to the workspace.
    if [[ -n "${BEHAT_TIMING_FILENAME}" ]]; then
        local timingpath="${WORKSPACE}/timing/${BEHAT_TIMING_FILENAME}"
        if [[ -f "${SHAREDDIR}"/timing.json ]]; then
            # Copy the timing file to the shared folder.
            cp "${SHAREDDIR}"/timing.json "${timingpath}"
        fi
    fi
}

# Calculate the command to run for Behat main execution,
# returning it in the passed array parameter.
# Parameters:
#   $1: The array to store the command.
function behat_main_command() {
    local -n _cmd=$1 # Return by nameref.

    # Pre-calculate a few format and profile options (they are different for parallel and non-parallel runs).
    local options=(
        --format=moodle_progress --out=std
    )
    local profile=()
    if [[ "${BEHAT_PARALLEL}" -eq 1 ]]; then
        options+=(
            --format=pretty --out=/shared/pretty.txt
            --format=junit --out=/shared/log.junit
        )
        profile+=(
            --profile="${BROWSER}"
        )
    else
        options+=(
            --format=pretty --out=/shared/pretty\{runprocess\}.txt
            --format=junit --out=/shared/log\{runprocess\}.junit
        )
        profile+=(
            --profile="${BROWSER}"\{runprocess\} --replace=\{runprocess\}
        )
    fi

    # Let's build the complete behat command for the 1st (parallel) run.
    _cmd=(
        php ${PUBLICROOT}admin/tool/behat/cli/run.php
    )

    # Add the options and profile.
    _cmd+=("${options[@]}")
    _cmd+=("${profile[@]}")

    # Add the suite to run.
    if [[ -n "${BEHAT_SUITE}" ]] && [[ "${BEHAT_SUITE}" != "ALL" ]]; then
        _cmd+=(--suite="${BEHAT_SUITE}")
    fi

    # Add the tags to run, excluding flaky scenarios.
    if [[ -n "${BEHAT_TAGS}" ]]; then
        _cmd+=(--tags="${BEHAT_TAGS}&&~@flaky")
    else
        _cmd+=(--tags="~@flaky")
    fi

    # Add the name to run.
    if [[ -n "${BEHAT_NAME}" ]]; then
        _cmd+=(--name="${BEHAT_NAME}")
    fi
}

# Calculate the command to run for Behat rerun execution,
# returning it in the passed array parameter.
# Parameters:
#   $1: The array to store the command.
#   $2: The rerun number.

function behat_rerun_command() {
    local -n _reruncmd=$1 # Return by nameref.
    local rerun=$2
    local process=$3

    # Pre-calculate a few config, format and profile options (they are different for parallel and non-parallel runs).
    local rerunconfig=()
    local rerunoptions=(
        --format=moodle_progress --out=std
    )
    local rerunprofile=()
    if [[ "${BEHAT_PARALLEL}" -eq 1 ]]; then
        # This was a single run.
        rerunconfig=(
            --config=/var/www/behatdata/run/behatrun/behat/behat.yml
        )
        rerunoptions+=(
            --format=pretty --out=/shared/pretty_rerun"${rerun}".txt
            --format=junit --out=/shared/log_rerun"${rerun}".junit
        )
        rerunprofile+=(
            --profile="${BROWSER}"
        )
    else
        # This was a parallel run.
        rerunconfig=(
            --config=/var/www/behatdata/run/behatrun\{runprocess\}/behat/behat.yml
        )
        rerunoptions+=(
            --format=pretty --out=/shared/pretty\{runprocess\}_rerun"${rerun}".txt
            --format=junit --out=/shared/log\{runprocess\}_rerun"${rerun}".junit
        )
        rerunprofile+=(
            --profile="${BROWSER}"\{runprocess\}
            --fromrun="${process}"  # Sadly, both --fromrun and --torun don't support the replace option,
            --torun="${process}"    # so we need to pass the process number manually.
            --replace=\{runprocess\}
        )
    fi

    # Let's build the complete behat command for the rerun.
    # Note that, as far as we are running the processes 1 by 1 (not in parallel),
    # we could be using `vendor/bin/behat` instead of `php admin/tool/behat/cli/run.php`.
    # But we are using the latter because it's the same command used for the main run
    # and, also, it automatically handles the file system links for the web server.
    # (output is a little bit uglier, but consistent with the main run).
    _reruncmd=(
        php ${PUBLICROOT}admin/tool/behat/cli/run.php --rerun
    )

    # Add the config, options and profile.
    _reruncmd+=("${rerunconfig[@]}")
    _reruncmd+=("${rerunoptions[@]}")
    _reruncmd+=("${rerunprofile[@]}")

    # Add the suite to run.
    if [[ -n "${BEHAT_SUITE}" ]] && [[ "${BEHAT_SUITE}" != "ALL" ]]; then
        _reruncmd+=(--suite="${BEHAT_SUITE}")
    fi

    # Add the tags to run.
    if [[ -n "${BEHAT_TAGS}" ]]; then
        _reruncmd+=(--tags="${BEHAT_TAGS}")
    fi

    # Add the name to run.
    if [[ -n "${BEHAT_NAME}" ]]; then
        _reruncmd+=(--name="${BEHAT_NAME}")
    fi
}
