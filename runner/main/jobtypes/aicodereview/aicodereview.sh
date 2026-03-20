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

# AI Code Review job type functions.
#
# This job type performs an AI-powered code review on the patch applied to the
# Moodle codebase. It uses an agentic AI loop where the model can request file
# contents, search the codebase, and iteratively build a structured review report
# following Moodle's peer review and integration review guidelines.

# AI Code Review needed variables to go to the env file.
function aicodereview_to_env_file() {
    local env=(
        DBTYPE
        DBTAG
        DBHOST
        DBNAME
        DBUSER
        DBPASS
        DBCOLLATION

        PUBLICROOT

        MOODLE_CONFIG
    )
    echo "${env[@]}"
}

# AI Code Review information to be added to the summary.
function aicodereview_to_summary() {
    echo "== Moodle branch (version.php): ${MOODLE_BRANCH}"
    echo "== PHP version: ${PHP_VERSION}"
    echo "== DBTYPE: ${DBTYPE}"
    echo "== DBTAG: ${DBTAG}"
    echo "== AI_MODEL: ${AI_MODEL}"
    echo "== REVIEW_TARGET_BRANCH: ${REVIEW_TARGET_BRANCH}"
    echo "== REVIEW_MAX_ITERATIONS: ${REVIEW_MAX_ITERATIONS}"
    echo "== JIRA_ISSUE: ${JIRA_ISSUE:-<not set>}"
    echo "== DRY_RUN: ${DRY_RUN}"
    echo "== MOODLE_CONFIG: ${MOODLE_CONFIG}"
}

# This job type defines the following env variables.
function aicodereview_env() {
    env=(
        AI_API_KEY
        AI_MODEL
        JIRA_ISSUE
        JIRA_API_TOKEN
        JIRA_BASE_URL
        REVIEW_TARGET_BRANCH
        REVIEW_MAX_ITERATIONS
        DRY_RUN
        EXITCODE
    )
    echo "${env[@]}"
}

# AI Code Review needed modules. Note that the order is important.
function aicodereview_modules() {
    local modules=(
        env
        summary
        moodle-branch
        docker
        docker-logs
        git
        plugins
        docker-database
        docker-php
        moodle-config
        moodle-core-copy
        docker-healthy
        docker-summary
    )
    echo "${modules[@]}"
}

# AI Code Review job type checks.
function aicodereview_check() {
    # Check all module dependencies.
    verify_modules $(aicodereview_modules)

    # These env variables must be set for the job to work.
    verify_env UUID ENVIROPATH WEBSERVER

    # AI_API_KEY is required unless in DRY_RUN mode. AI_MODEL has a default set in _config.
    if [[ "${DRY_RUN:-0}" != "1" ]]; then
        verify_env AI_API_KEY
        # verify_env only checks declaration (via -v), not value. Since the framework
        # initialises env vars to empty strings, we must also check it is non-empty.
        if [[ -z "${AI_API_KEY:-}" ]]; then
            print_error "AI_API_KEY is empty. Please export a valid API key."
            exit 1
        fi
    fi

    # Verify that required utilities are available on the host.
    verify_utilities curl jq
}

# AI Code Review job type config.
function aicodereview_config() {
    # Apply defaults.
    EXITCODE=0
    AI_MODEL="${AI_MODEL:-claude-sonnet-4-20250514}"
    REVIEW_TARGET_BRANCH="${REVIEW_TARGET_BRANCH:-origin/main}"
    REVIEW_MAX_ITERATIONS="${REVIEW_MAX_ITERATIONS:-10}"
    JIRA_ISSUE="${JIRA_ISSUE:-}"
    JIRA_API_TOKEN="${JIRA_API_TOKEN:-}"
    JIRA_BASE_URL="${JIRA_BASE_URL:-https://moodle.atlassian.net}"
    DRY_RUN="${DRY_RUN:-0}"
}

# AI Code Review job type setup.
function aicodereview_setup() {
    echo
    echo ">>> startsection Initialising AI Code Review environment at $(date)<<<"
    echo "============================================================================"

    # Ensure the shared directory exists and is writable.
    mkdir -p "${SHAREDDIR}"
    chmod -R 2777 "${SHAREDDIR}"

    # Install the Moodle database (some code paths and checks may need it).
    echo "Installing Moodle database..."
#    docker exec -t -u www-data "${WEBSERVER}" \
#        php public/admin/cli/install_database.php \
#            --agree-license \
#            --fullname="AI Code Review" \
#            --shortname="aicodereview" \
#            --adminuser=admin \
#            --adminpass=adminpass

    # Run the moodle install_database.php.
    local initcmd
    aicodereview_initcmd initcmd # By nameref.
    echo "Running: ${initcmd[*]}"
    docker exec -t -u www-data "${WEBSERVER}" "${initcmd[@]}"

    # Extract the git diff from the WEBSERVER container.
    # Note: We use -i (no TTY) instead of -t to avoid the pager and ANSI escape codes
    # being embedded in the output. We also pass --no-pager and --no-color explicitly.
    echo "Extracting git diff against ${REVIEW_TARGET_BRANCH}..."
    docker exec -i -u www-data "${WEBSERVER}" \
        git --no-pager diff --no-color "${REVIEW_TARGET_BRANCH}" -- . > "${SHAREDDIR}/diff.patch" 2>/dev/null || true

    # Get diff stats for the summary.
    docker exec -i -u www-data "${WEBSERVER}" \
        git --no-pager diff --no-color --stat "${REVIEW_TARGET_BRANCH}" -- . > "${SHAREDDIR}/diff_stats.txt" 2>/dev/null || true

    # Get the list of changed files.
    docker exec -i -u www-data "${WEBSERVER}" \
        git --no-pager diff --no-color --name-only "${REVIEW_TARGET_BRANCH}" -- . > "${SHAREDDIR}/changed_files.txt" 2>/dev/null || true

    # Get the git log for the patch commits.
    docker exec -i -u www-data "${WEBSERVER}" \
        git --no-pager log --no-color --oneline "${REVIEW_TARGET_BRANCH}..HEAD" > "${SHAREDDIR}/patch_log.txt" 2>/dev/null || true

    local diffsize
    diffsize=$(wc -c < "${SHAREDDIR}/diff.patch" 2>/dev/null || echo 0)
    local filecount
    filecount=$(wc -l < "${SHAREDDIR}/changed_files.txt" 2>/dev/null || echo 0)

    echo "Diff size: ${diffsize} bytes"
    echo "Files changed: ${filecount}"

    if [[ "${diffsize}" -eq 0 ]]; then
        echo "WARNING: No diff detected against ${REVIEW_TARGET_BRANCH}. The review may not be meaningful."
    fi

    # Fetch Jira context if an issue key is configured.
    if [[ -n "${JIRA_ISSUE}" ]]; then
        echo "Fetching Jira context for ${JIRA_ISSUE}..."
        # Source the jira helper.
        source "${BASEDIR}/jobtypes/aicodereview/jira.sh"
        fetch_jira_context "${JIRA_ISSUE}" > "${SHAREDDIR}/jira_context.txt" 2>/dev/null || {
            echo "WARNING: Failed to fetch Jira context. Proceeding without it."
            echo "Jira context not available." > "${SHAREDDIR}/jira_context.txt"
        }
    else
        echo "No Jira issue configured. Proceeding without issue context."
        echo "Jira context not available." > "${SHAREDDIR}/jira_context.txt"
    fi

    echo "============================================================================"
    echo ">>> stopsection <<<"
}
function aicodereview_initcmd() {
    local -n cmd=$1

    # Build the complete init command.
    cmd=(
        php admin/cli/install_database.php \
            --agree-license \
            --fullname="AI Code Review"\
            --shortname="aicodereview" \
            --adminuser=admin \
            --adminpass=adminpass
    )
}

# AI Code Review job type run.
function aicodereview_run() {
    echo
    echo ">>> startsection Starting AI Code Review at $(date) <<<"
    echo "============================================================================"

    # Source the tools and agent scripts.
    source "${BASEDIR}/jobtypes/aicodereview/tools.sh"

    if [[ "${DRY_RUN}" == "1" ]]; then
        echo "DRY_RUN mode: Skipping AI API calls."
        echo "Generating dry-run report with gathered context..."
        aicodereview_dry_run
    else
        # Run the agentic review loop.
        source "${BASEDIR}/jobtypes/aicodereview/agent.sh"
        run_agent_loop
    fi

    EXITCODE=$?

    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# AI Code Review job type teardown.
function aicodereview_teardown() {
    echo
    echo ">>> startsection Finishing AI Code Review at $(date) <<<"
    echo "============================================================================"

    # Display the review report if it exists.
    if [[ -f "${SHAREDDIR}/review_report.md" ]]; then
        echo "Review report:"
        echo "============================================================================"
        cat "${SHAREDDIR}/review_report.md"
        echo
        echo "============================================================================"

        # Parse the verdict from the report to set EXITCODE.
        if grep -q '"verdict":\s*"APPROVE"' "${SHAREDDIR}/review_report.md" 2>/dev/null || \
           grep -q '^\*\*Verdict\*\*: APPROVE' "${SHAREDDIR}/review_report.md" 2>/dev/null; then
            echo "Review verdict: APPROVE"
            EXITCODE=0
        elif grep -q '"verdict":\s*"REQUEST_CHANGES"' "${SHAREDDIR}/review_report.md" 2>/dev/null || \
             grep -q '^\*\*Verdict\*\*: REQUEST CHANGES' "${SHAREDDIR}/review_report.md" 2>/dev/null; then
            echo "Review verdict: REQUEST CHANGES"
            EXITCODE=1
        else
            echo "WARNING: Could not determine verdict from report. Defaulting to REQUEST CHANGES."
            EXITCODE=1
        fi
    else
        echo "WARNING: No review report was generated."
        EXITCODE=1
    fi

    echo "== Exit code: ${EXITCODE}"
    echo "============================================================================"
    echo ">>> stopsection <<<"
}

# Generate a dry-run report without calling the AI API.
function aicodereview_dry_run() {
    local report="${SHAREDDIR}/review_report.md"
    local jira_label="${JIRA_ISSUE:-Patch Review}"

    {
        echo "# AI Code Review: ${jira_label} — Dry Run"
        echo ""
        echo "## Review Summary"
        echo "**Verdict**: APPROVE"
        echo "**Confidence**: LOW"
        echo "**Reviewed at**: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo "**Commit**: ${GIT_COMMIT:-unknown}"
        echo "**Model**: DRY_RUN (no AI model used)"
        echo ""
        echo "## Change Overview"
        echo "This is a dry-run report. No AI analysis was performed."
        echo ""
        echo "## Diff Statistics"
        echo '```'
        cat "${SHAREDDIR}/diff_stats.txt" 2>/dev/null || echo "No diff stats available."
        echo '```'
        echo ""
        echo "## Files Changed"
        cat "${SHAREDDIR}/changed_files.txt" 2>/dev/null || echo "No changed files detected."
        echo ""
        echo "## Patch Commits"
        echo '```'
        cat "${SHAREDDIR}/patch_log.txt" 2>/dev/null || echo "No patch commits detected."
        echo '```'
        echo ""
        echo "## Jira Context"
        cat "${SHAREDDIR}/jira_context.txt" 2>/dev/null || echo "No Jira context available."
        echo ""
        echo "## Diff"
        echo '```diff'
        head -c 100000 "${SHAREDDIR}/diff.patch" 2>/dev/null || echo "No diff available."
        echo '```'
        echo ""
        echo "## Recommendation"
        echo "**APPROVE** — Dry run mode. No actual review was performed."
    } > "${report}"

    cat "${report}"
    return 0
}

