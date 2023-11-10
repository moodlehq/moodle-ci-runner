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

# Plugins module functions.

# This module defines the following env variables.
# The PLUGINSTOINSTALL variable could be set to install external plugins in the CODEDIR folder.
# The following information is needed for each plugin: git repo, folder and branch (optional).
# The plugin fields should be separated by "|" and each plugin should be separated using ";":
# "gitrepoplugin1|gitfolderplugin1|gitbranchplugin1;gitrepoplugin2|gitfolderplugin2|gitbranchplugin2[...]"
#
# Example: "https://github.com/moodlehq/moodle-local_mobile.git|local/mobile|MOODLE_37_STABLE;git@github.com:jleyva/moodle-block_configurablereports.git|blocks/configurable_reports"
#
# The PLUGINSDIR is the directory where the plugins will be downloaded (or made available
# by any other method). In a moodle-like structure (mod, local, etc).
function plugins_env() {
    env=(
        PLUGINSTOINSTALL
        PLUGINSDIR
    )
    echo "${env[@]}"
}

# Plugins module checks.
function plugins_check() {
    # Check all module dependencies.
    verify_modules docker git

    # These env variables must be set for the module to work.
    verify_env WORKSPACE
}

# Plugins module config.
function plugins_config() {
    # Apply some defaults.
    PLUGINSTOINSTALL="${PLUGINSTOINSTALL:-}"
    PLUGINSDIR="${PLUGINSDIR:-${WORKSPACE}/plugins}"
}

# Plugins module setup, download all the requested plugins to workspace area.
function plugins_setup() {
    # Create the plugins directory. Always.
    mkdir -p "${PLUGINSDIR}"
    # Download the plugins, if any.
    if [[ -n "${PLUGINSTOINSTALL}" ]]; then
        local plugins=
        local plugin=
        echo ">>> startsection Download external plugins <<<"
        echo "============================================================================"
        # Download all the plugins in a temporary folder.
        IFS=';' read -ra plugins <<< "${PLUGINSTOINSTALL}"
        for plugin in "${plugins[@]}"; do
            local gitrepo=
            local gitbranch=
            local directory=
            local branch=
            local singlebranch=
            if  [[ -n "${plugin}" ]]; then
                gitrepo=$(echo "$plugin" | cut -f1 -d'|')
                directory=$(echo "$plugin" | cut -f2 -d'|')
                gitbranch=$(echo "$plugin" | cut -f3 -d'|')
                echo "Cloning ${gitrepo}/${gitbranch}"

                if [[ -n "${gitbranch}" ]]; then
                    # Only download this branch.
                    branch="--branch=${gitbranch}"
                    singlebranch="--single-branch"
                fi

                # Clone the plugin repository in the defined folder.
                git clone --quiet "${branch}" "${singlebranch}" "${gitrepo}" "${PLUGINSDIR}/${directory}"
                echo "Cloned. HEAD is @ $(cd "${PLUGINSDIR}/${directory}" && git rev-parse HEAD)"
                echo
            fi
        done
        echo "============================================================================"
        echo ">>> stopsection <<<"
    fi
}