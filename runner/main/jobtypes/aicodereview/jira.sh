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

# Jira API integration helpers for the AI Code Review job type.
#
# Fetches issue context from the Atlassian REST API to provide the AI reviewer
# with information about the issue being addressed by the patch.

# Fetch Jira issue context and output a human-readable summary.
# Arguments:
#   $1 - Jira issue key (e.g., "MDL-12345").
# Requires:
#   JIRA_API_TOKEN - Bearer token for the Jira API.
#   JIRA_BASE_URL  - Base URL of the Jira instance.
# Outputs:
#   Formatted issue context to stdout.
function fetch_jira_context() {
    local issue_key="${1:-}"

    if [[ -z "${issue_key}" ]]; then
        echo "ERROR: No Jira issue key provided."
        return 1
    fi


    local base_url="${JIRA_BASE_URL:-https://moodle.atlassian.net}"
    local fields="summary,description,comment,issuetype,priority,status,components,labels,fixVersions"
    local api_url="${base_url}/rest/api/3/issue/${issue_key}?fields=${fields}"

    echo "Fetching Jira issue: ${issue_key}..."

    # Build the auth arguments. Support three formats:
    #   1. "user@email:api-token" — Atlassian Cloud Basic auth (email + API token).
    #   2. "Bearer <token>"       — PAT / OAuth bearer token.
    #   3. Raw token string       — Treated as a Bearer token.
    #   4. Empty / not set        — No auth (works for public Jira instances like moodle.atlassian.net).
    local -a auth_args=()
    if [[ -n "${JIRA_API_TOKEN:-}" ]]; then
        if [[ "${JIRA_API_TOKEN}" == *:* ]]; then
            # Contains a colon — treat as user:token for Basic auth.
            auth_args=(-u "${JIRA_API_TOKEN}")
        elif [[ "${JIRA_API_TOKEN}" == Bearer\ * ]]; then
            auth_args=(-H "Authorization: ${JIRA_API_TOKEN}")
        else
            auth_args=(-H "Authorization: Bearer ${JIRA_API_TOKEN}")
        fi
    fi

    local response
    response=$(curl -s --max-time 30 \
        "${auth_args[@]}" \
        -H "Accept: application/json" \
        "${api_url}" 2>&1) || {
        echo "ERROR: Failed to fetch Jira issue ${issue_key}."
        return 1
    }

    # Check if the response is valid JSON.
    if ! echo "${response}" | jq empty 2>/dev/null; then
        echo "ERROR: Jira API returned non-JSON response (possible auth failure)."
        echo "Response preview: $(echo "${response}" | head -c 200)"
        return 1
    fi

    # Check for errors in the response.
    local error_messages
    error_messages=$(echo "${response}" | jq -r '.errorMessages[]? // empty' 2>/dev/null)
    if [[ -n "${error_messages}" ]]; then
        echo "ERROR: Jira API returned errors: ${error_messages}"
        return 1
    fi

    # Parse the response and format it.
    format_jira_context "${response}" "${issue_key}"
}

# Format a Jira API JSON response into a human-readable summary.
# Arguments:
#   $1 - JSON response from the Jira API.
#   $2 - Issue key.
# Outputs:
#   Formatted text to stdout.
function format_jira_context() {
    local json="${1:-}"
    local issue_key="${2:-}"

    # Extract fields using jq.
    local summary issuetype priority status components labels fix_versions

    summary=$(echo "${json}" | jq -r '.fields.summary // "N/A"')
    issuetype=$(echo "${json}" | jq -r '.fields.issuetype.name // "N/A"')
    priority=$(echo "${json}" | jq -r '.fields.priority.name // "N/A"')
    status=$(echo "${json}" | jq -r '.fields.status.name // "N/A"')

    components=$(echo "${json}" | jq -r '[.fields.components[]?.name] | join(", ") // "None"')
    labels=$(echo "${json}" | jq -r '[.fields.labels[]?] | join(", ") // "None"')
    fix_versions=$(echo "${json}" | jq -r '[.fields.fixVersions[]?.name] | join(", ") // "None"')

    # Extract description (Atlassian Document Format → plain text).
    local description
    description=$(extract_adf_text "${json}" ".fields.description")

    # Extract comments (last 5 most recent).
    local comments
    comments=$(extract_jira_comments "${json}")

    # Output formatted context.
    echo "=== Jira Issue Context ==="
    echo "Issue: ${issue_key}"
    echo "Summary: ${summary}"
    echo "Type: ${issuetype}"
    echo "Priority: ${priority}"
    echo "Status: ${status}"
    echo "Components: ${components}"
    echo "Labels: ${labels}"
    echo "Fix Versions: ${fix_versions}"
    echo ""
    echo "=== Description ==="
    echo "${description}"
    echo ""
    echo "=== Recent Comments ==="
    echo "${comments}"
}

# Extract plain text from an Atlassian Document Format (ADF) field.
# ADF is a JSON tree structure; we recursively extract all text nodes.
# Arguments:
#   $1 - Full JSON response.
#   $2 - jq path to the ADF field (e.g., ".fields.description").
# Outputs:
#   Plain text representation on stdout.
function extract_adf_text() {
    local json="${1:-}"
    local jq_path="${2:-.fields.description}"

    local text
    # Recursively extract all "text" values from the ADF content tree.
    # This is a simplified extraction that captures the main text content.
    text=$(echo "${json}" | jq -r "
        ${jq_path} |
        if . == null then
            \"No description available.\"
        else
            [.. | .text? // empty] | join(\"\")
        end
    " 2>/dev/null)

    if [[ -z "${text}" ]] || [[ "${text}" == "null" ]]; then
        echo "No description available."
    else
        echo "${text}"
    fi
}

# Extract recent comments from the Jira issue response.
# Arguments:
#   $1 - Full JSON response.
# Outputs:
#   Formatted comments to stdout (last 5).
function extract_jira_comments() {
    local json="${1:-}"

    local comment_count
    comment_count=$(echo "${json}" | jq -r '.fields.comment.comments | length // 0' 2>/dev/null)

    if [[ "${comment_count}" -eq 0 ]] || [[ "${comment_count}" == "null" ]]; then
        echo "No comments."
        return
    fi

    # Get the last 5 comments.
    local start_index=$((comment_count > 5 ? comment_count - 5 : 0))

    echo "${json}" | jq -r "
        .fields.comment.comments[${start_index}:] |
        .[] |
        \"--- Comment by \" + (.author.displayName // \"Unknown\") + \" (\" + (.created // \"unknown date\") + \") ---\n\" +
        ([.. | .text? // empty] | join(\"\")) + \"\n\"
    " 2>/dev/null || echo "Failed to parse comments."
}

