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

# Agentic AI review loop for the AI Code Review job type.
#
# This script manages the conversation with the AI model, parsing tool calls
# from responses and executing them against the Moodle codebase via the
# tools defined in tools.sh.
#
# The loop continues until the AI produces a FINAL_REVIEW tool call or
# REVIEW_MAX_ITERATIONS is reached.
#
# Requires: tools.sh to be sourced before this script.

# AI API endpoint.
AI_API_URL="${AI_API_URL:-https://ai.moodle.com/v1/chat/completions}"

# API request timeout in seconds.
AI_API_TIMEOUT="${AI_API_TIMEOUT:-120}"

# The conversation history is stored as a JSON file.
CONVERSATION_FILE=""

# Initialise the conversation history file.
function agent_init_conversation() {
    CONVERSATION_FILE=$(mktemp "${SHAREDDIR}/conversation_XXXXXX.json")
    echo '[]' > "${CONVERSATION_FILE}"
}

# Append a message to the conversation history.
# Arguments:
#   $1 - Role ("system", "user", "assistant").
#   $2 - Content (text).
function agent_append_message() {
    local role="${1}"
    local content="${2}"

    # Write the raw content to a temp file so jq can read it safely.
    # Using printf '%s' avoids echo's issues with special characters and large strings.
    local tmpfile
    tmpfile=$(mktemp "${SHAREDDIR}/msg_XXXXXX.tmp")
    printf '%s' "${content}" > "${tmpfile}"

    # Use jq's --rawfile to slurp the content as a string (avoids shell escaping issues).
    # --rawfile reads a file and binds its contents as a string variable.
    local outfile
    outfile=$(mktemp "${SHAREDDIR}/conv_XXXXXX.tmp")
    jq --arg role "${role}" --rawfile content "${tmpfile}" \
        '. + [{"role": $role, "content": $content}]' \
        "${CONVERSATION_FILE}" > "${outfile}" 2>/dev/null || {
        echo "ERROR: Failed to append message to conversation." >&2
        rm -f "${tmpfile}" "${outfile}"
        return 1
    }
    mv "${outfile}" "${CONVERSATION_FILE}"
    rm -f "${tmpfile}"
}

# Build the system prompt from the template and context.
# Outputs:
#   The complete system prompt text.
function agent_build_system_prompt() {
    local system_prompt_template="${BASEDIR}/jobtypes/aicodereview/system_prompt.txt"
    local peer_review_guidelines="${BASEDIR}/jobtypes/aicodereview/guidelines/peer_review.md"
    local integration_review_guidelines="${BASEDIR}/jobtypes/aicodereview/guidelines/integration_review.md"

    local prompt=""

    # Read the system prompt template.
    if [[ -f "${system_prompt_template}" ]]; then
        prompt=$(cat "${system_prompt_template}")
    else
        echo "ERROR: System prompt template not found: ${system_prompt_template}" >&2
        return 1
    fi

    # Append condensed review guidelines.
    prompt+=$'\n\n## Peer Review Checklist\n'
    if [[ -f "${peer_review_guidelines}" ]]; then
        prompt+=$(cat "${peer_review_guidelines}")
    fi

    prompt+=$'\n\n## Integration Review Checklist\n'
    if [[ -f "${integration_review_guidelines}" ]]; then
        prompt+=$(cat "${integration_review_guidelines}")
    fi

    echo "${prompt}"
}

# Build the initial user message with the diff and context.
# Outputs:
#   The initial user message text.
function agent_build_initial_message() {
    local message=""

    # Add Jira context if available.
    local jira_context=""
    if [[ -f "${SHAREDDIR}/jira_context.txt" ]]; then
        jira_context=$(cat "${SHAREDDIR}/jira_context.txt")
    fi
    if [[ -n "${jira_context}" ]] && [[ "${jira_context}" != "Jira context not available." ]]; then
        message+="## Jira Issue Context"$'\n'
        message+="${jira_context}"$'\n\n'
    fi

    # Add patch commit log.
    if [[ -f "${SHAREDDIR}/patch_log.txt" ]] && [[ -s "${SHAREDDIR}/patch_log.txt" ]]; then
        message+="## Patch Commits"$'\n'
        message+='```'$'\n'
        message+=$(cat "${SHAREDDIR}/patch_log.txt")
        message+=$'\n```\n\n'
    fi

    # Add diff statistics.
    if [[ -f "${SHAREDDIR}/diff_stats.txt" ]] && [[ -s "${SHAREDDIR}/diff_stats.txt" ]]; then
        message+="## Diff Statistics"$'\n'
        message+='```'$'\n'
        message+=$(cat "${SHAREDDIR}/diff_stats.txt")
        message+=$'\n```\n\n'
    fi

    # Add changed files list.
    if [[ -f "${SHAREDDIR}/changed_files.txt" ]] && [[ -s "${SHAREDDIR}/changed_files.txt" ]]; then
        message+="## Changed Files"$'\n'
        message+=$(cat "${SHAREDDIR}/changed_files.txt")
        message+=$'\n\n'
    fi

    # Add the diff itself. Truncate if too large (> 200KB).
    local diff_content=""
    local max_diff_size=200000
    if [[ -f "${SHAREDDIR}/diff.patch" ]] && [[ -s "${SHAREDDIR}/diff.patch" ]]; then
        local diff_size
        diff_size=$(wc -c < "${SHAREDDIR}/diff.patch")
        if [[ ${diff_size} -gt ${max_diff_size} ]]; then
            message+="## Code Diff (TRUNCATED — ${diff_size} bytes total, showing first ${max_diff_size} bytes)"$'\n'
            message+="**Note**: The diff is very large. Use the READ_FILE and GREP_SEARCH tools to examine specific files in detail."$'\n'
            message+='```diff'$'\n'
            diff_content=$(head -c "${max_diff_size}" "${SHAREDDIR}/diff.patch")
            message+="${diff_content}"
            message+=$'\n```\n'
            message+=$'\n[DIFF TRUNCATED — use tools to examine remaining files]\n'
        else
            message+="## Code Diff"$'\n'
            message+='```diff'$'\n'
            diff_content=$(cat "${SHAREDDIR}/diff.patch")
            message+="${diff_content}"
            message+=$'\n```\n'
        fi
    else
        message+="## Code Diff"$'\n'
        message+="No diff detected. The codebase may be unchanged from ${REVIEW_TARGET_BRANCH}."$'\n'
    fi

    message+=$'\n'
    message+="Please review this patch following the Moodle peer review and integration review guidelines. "
    message+="Use the available tools to examine the codebase for additional context as needed. "
    message+="When you have gathered enough context, produce your final review using the FINAL_REVIEW tool."

    echo "${message}"
}

# Send the current conversation to the AI API and get the response.
# Outputs:
#   The full API response JSON on stdout.
# Returns:
#   0 on success, 1 on failure.
function agent_api_call() {
    # Build the messages array from the conversation file.
    local messages
    messages=$(cat "${CONVERSATION_FILE}")

    # Build the request body.
    local request_body
    request_body=$(jq -n \
        --arg model "${AI_MODEL}" \
        --argjson messages "${messages}" \
        '{
            "model": $model,
            "messages": $messages,
            "temperature": 0.2,
            "max_tokens": 16384
        }')

    # Make the API call.
    local response
    local http_code
    local response_file
    response_file=$(mktemp "${SHAREDDIR}/api_response_XXXXXX.json")

    # Normalise the Authorization header value. If AI_API_KEY already
    # contains the "Bearer " prefix, use it as-is; otherwise prepend it.
    local auth_header="${AI_API_KEY}"
    if [[ "${auth_header}" != Bearer\ * ]]; then
        auth_header="Bearer ${auth_header}"
    fi

    http_code=$(curl -s -w '%{http_code}' \
        --max-time "${AI_API_TIMEOUT}" \
        -H "Content-Type: application/json" \
        -H "Authorization: ${auth_header}" \
        -d "${request_body}" \
        -o "${response_file}" \
        "${AI_API_URL}" 2>&1) || {
        echo "ERROR: API call failed (curl error)." >&2
        rm -f "${response_file}"
        return 1
    }

    if [[ "${http_code}" != "200" ]]; then
        echo "ERROR: API returned HTTP ${http_code}." >&2
        local error_detail
        error_detail=$(cat "${response_file}" 2>/dev/null | jq -r '.error.message // .error // empty' 2>/dev/null)
        if [[ -n "${error_detail}" ]]; then
            echo "API Error: ${error_detail}" >&2
        fi
        rm -f "${response_file}"
        return 1
    fi

    cat "${response_file}"
    rm -f "${response_file}"
}

# Extract the assistant's message content from an API response.
# Arguments:
#   $1 - API response JSON.
# Outputs:
#   The message content on stdout.
function agent_extract_content() {
    local response="${1}"
    echo "${response}" | jq -r '.choices[0].message.content // empty'
}

# Parse tool calls from the assistant's response content.
# The AI may embed one or more JSON objects like:
#   {"tool": "TOOL_NAME", "args": {...}}
# Arguments:
#   $1 - Assistant message content.
# Outputs:
#   JSON array of tool call objects on stdout.
function agent_parse_tool_calls() {
    local content="${1}"

    # Extract JSON objects that look like tool calls.
    # We look for {"tool": "...", "args": {...}} patterns.
    # Use a Python one-liner for robust JSON extraction since jq can't parse
    # embedded JSON within arbitrary text.
    local tool_calls
    tool_calls=$(python3 -c "
import json, re, sys

content = sys.stdin.read()
# Find all JSON-like objects in the content.
# Match balanced braces (simple approach — handles most cases).
results = []
# Try to find tool call patterns.
for match in re.finditer(r'\{[^{}]*\"tool\"\s*:\s*\"[A-Z_]+\"[^{}]*\}', content):
    try:
        obj = json.loads(match.group())
        if 'tool' in obj:
            results.append(obj)
    except json.JSONDecodeError:
        pass

# Also try multi-line JSON blocks (code blocks).
for match in re.finditer(r'\`\`\`(?:json)?\s*(\{.*?\})\s*\`\`\`', content, re.DOTALL):
    try:
        obj = json.loads(match.group(1))
        if 'tool' in obj:
            results.append(obj)
    except json.JSONDecodeError:
        pass

# Also try to find JSON that spans multiple lines with nested args.
for match in re.finditer(r'\{\s*\"tool\"\s*:\s*\"[A-Z_]+\"\s*,\s*\"args\"\s*:\s*\{[^}]*\}\s*\}', content, re.DOTALL):
    try:
        obj = json.loads(match.group())
        if 'tool' in obj and obj not in results:
            results.append(obj)
    except json.JSONDecodeError:
        pass

# Deduplicate (by converting to tuples of sorted items).
seen = set()
unique = []
for r in results:
    key = json.dumps(r, sort_keys=True)
    if key not in seen:
        seen.add(key)
        unique.append(r)

print(json.dumps(unique))
" <<< "${content}" 2>/dev/null) || {
        echo "[]"
        return
    }

    if [[ -z "${tool_calls}" ]]; then
        echo "[]"
    else
        echo "${tool_calls}"
    fi
}

# Execute a single tool call and return the result.
# Arguments:
#   $1 - Tool call JSON object.
# Outputs:
#   Tool result on stdout.
function agent_execute_tool() {
    local tool_json="${1}"

    local tool_name args_json
    tool_name=$(echo "${tool_json}" | jq -r '.tool // empty')
    args_json=$(echo "${tool_json}" | jq -r '.args // {}')

    if [[ -z "${tool_name}" ]]; then
        echo "ERROR: No tool name in tool call."
        return
    fi

    echo "  >> Executing tool: ${tool_name}" >&2

    # Dispatch the tool.
    dispatch_tool "${tool_name}" "${args_json}"
}

# Run the main agentic review loop.
# This is the entry point called from aicodereview_run().
# Returns:
#   0 on success (review produced), 1 on failure.
function run_agent_loop() {
    local max_iterations="${REVIEW_MAX_ITERATIONS}"
    local iteration=0
    local review_complete=0

    echo "Starting agentic review loop (max ${max_iterations} iterations)..."
    echo ""

    # Initialise conversation.
    agent_init_conversation

    # Build and add the system prompt.
    local system_prompt
    system_prompt=$(agent_build_system_prompt) || {
        echo "ERROR: Failed to build system prompt."
        return 1
    }
    agent_append_message "system" "${system_prompt}"

    # Build and add the initial user message (diff + context).
    local initial_message
    initial_message=$(agent_build_initial_message)
    agent_append_message "user" "${initial_message}"

    # Main loop.
    while [[ ${iteration} -lt ${max_iterations} ]]; do
        iteration=$((iteration + 1))
        echo "--- Iteration ${iteration}/${max_iterations} ---"

        # Call the AI API.
        local response
        response=$(agent_api_call) || {
            echo "ERROR: API call failed on iteration ${iteration}. Retrying..."
            # Simple retry with backoff.
            sleep $((iteration * 2))
            response=$(agent_api_call) || {
                echo "ERROR: API call failed again. Aborting."
                agent_generate_error_report "API call failed after retry on iteration ${iteration}."
                return 1
            }
        }

        # Extract the assistant's message.
        local assistant_content
        assistant_content=$(agent_extract_content "${response}")

        if [[ -z "${assistant_content}" ]]; then
            echo "WARNING: Empty response from AI on iteration ${iteration}."
            agent_append_message "user" "Your previous response was empty. Please continue with your review."
            continue
        fi

        # Add the assistant's message to the conversation.
        agent_append_message "assistant" "${assistant_content}"

        # Parse tool calls from the response.
        local tool_calls
        tool_calls=$(agent_parse_tool_calls "${assistant_content}")

        local tool_count
        tool_count=$(echo "${tool_calls}" | jq 'length')

        if [[ ${tool_count} -eq 0 ]]; then
            # No tool calls — check if the response contains a review-like structure.
            # The AI might have produced the review directly without using the FINAL_REVIEW tool.
            if echo "${assistant_content}" | grep -q "## Review Summary" && \
               echo "${assistant_content}" | grep -q "Verdict"; then
                echo "AI produced a review without FINAL_REVIEW tool. Extracting..."
                echo "${assistant_content}" > "${SHAREDDIR}/review_report.md"
                review_complete=1
                break
            fi

            # Ask the AI to either use a tool or produce the final review.
            agent_append_message "user" \
                "Please either use one of the available tools to gather more context, or produce your final review using the FINAL_REVIEW tool. Remember to output a JSON tool call like: {\"tool\": \"FINAL_REVIEW\", \"args\": {\"verdict\": \"APPROVE\", \"confidence\": \"HIGH\", \"report\": \"<full markdown report>\"}}"
            continue
        fi

        # Process each tool call.
        local i=0
        local tool_results=""
        while [[ ${i} -lt ${tool_count} ]]; do
            local tool_call
            tool_call=$(echo "${tool_calls}" | jq ".[$i]")
            local tool_name
            tool_name=$(echo "${tool_call}" | jq -r '.tool')

            # Check for FINAL_REVIEW.
            if [[ "${tool_name}" == "FINAL_REVIEW" ]]; then
                echo "AI produced FINAL_REVIEW on iteration ${iteration}."
                local verdict confidence report
                verdict=$(echo "${tool_call}" | jq -r '.args.verdict // "REQUEST_CHANGES"')
                confidence=$(echo "${tool_call}" | jq -r '.args.confidence // "MEDIUM"')
                report=$(echo "${tool_call}" | jq -r '.args.report // empty')

                if [[ -n "${report}" ]]; then
                    echo "${report}" > "${SHAREDDIR}/review_report.md"
                else
                    # Build a report from the available information.
                    agent_generate_report_from_verdict "${verdict}" "${confidence}" "${assistant_content}"
                fi
                review_complete=1
                break 2  # Break out of both loops.
            fi

            # Execute the tool.
            local result
            result=$(agent_execute_tool "${tool_call}")

            # Accumulate tool results.
            tool_results+="### Tool: ${tool_name}"$'\n'
            tool_results+="${result}"$'\n\n'

            i=$((i + 1))
        done

        # If we have tool results, send them back to the AI.
        if [[ -n "${tool_results}" ]] && [[ ${review_complete} -eq 0 ]]; then
            agent_append_message "user" "Here are the results of your tool calls:"$'\n\n'"${tool_results}"$'\n'"Continue your review. Use more tools if needed, or produce your FINAL_REVIEW when ready."
        fi
    done

    if [[ ${review_complete} -eq 0 ]]; then
        echo "WARNING: Max iterations (${max_iterations}) reached without a final review."
        echo "Asking AI for a final summary..."

        # One last attempt to get the review.
        agent_append_message "user" \
            "You have reached the maximum number of iterations. Please produce your FINAL_REVIEW now with your best assessment based on the context you have gathered so far. Output: {\"tool\": \"FINAL_REVIEW\", \"args\": {\"verdict\": \"APPROVE|REQUEST_CHANGES\", \"confidence\": \"HIGH|MEDIUM|LOW\", \"report\": \"<full markdown report>\"}}"

        local final_response
        final_response=$(agent_api_call) || {
            agent_generate_error_report "Final API call failed after max iterations."
            return 1
        }

        local final_content
        final_content=$(agent_extract_content "${final_response}")

        if [[ -n "${final_content}" ]]; then
            agent_append_message "assistant" "${final_content}"

            # Try to extract the FINAL_REVIEW.
            local final_tool_calls
            final_tool_calls=$(agent_parse_tool_calls "${final_content}")
            local final_tool_count
            final_tool_count=$(echo "${final_tool_calls}" | jq 'length')

            if [[ ${final_tool_count} -gt 0 ]]; then
                local final_tool
                final_tool=$(echo "${final_tool_calls}" | jq '.[0]')
                local final_tool_name
                final_tool_name=$(echo "${final_tool}" | jq -r '.tool')

                if [[ "${final_tool_name}" == "FINAL_REVIEW" ]]; then
                    local report
                    report=$(echo "${final_tool}" | jq -r '.args.report // empty')
                    if [[ -n "${report}" ]]; then
                        echo "${report}" > "${SHAREDDIR}/review_report.md"
                        review_complete=1
                    fi
                fi
            fi

            # If still no structured review, use the raw content.
            if [[ ${review_complete} -eq 0 ]]; then
                if echo "${final_content}" | grep -q "Verdict"; then
                    echo "${final_content}" > "${SHAREDDIR}/review_report.md"
                    review_complete=1
                fi
            fi
        fi

        if [[ ${review_complete} -eq 0 ]]; then
            agent_generate_error_report "Max iterations reached and AI did not produce a final review."
            return 1
        fi
    fi

    echo ""
    echo "Review complete after ${iteration} iteration(s)."

    # Clean up the conversation file (keep for debugging).
    echo "Conversation log saved to: ${CONVERSATION_FILE}"

    return 0
}

# Generate a report from a verdict when the AI didn't provide a full report.
# Arguments:
#   $1 - Verdict (APPROVE or REQUEST_CHANGES).
#   $2 - Confidence (HIGH, MEDIUM, LOW).
#   $3 - The raw assistant content that contained the verdict.
function agent_generate_report_from_verdict() {
    local verdict="${1:-REQUEST_CHANGES}"
    local confidence="${2:-MEDIUM}"
    local raw_content="${3:-}"
    local jira_label="${JIRA_ISSUE:-Patch Review}"

    local verdict_display
    if [[ "${verdict}" == "APPROVE" ]]; then
        verdict_display="APPROVE"
    else
        verdict_display="REQUEST CHANGES"
    fi

    {
        echo "# AI Code Review: ${jira_label}"
        echo ""
        echo "## Review Summary"
        echo "**Verdict**: ${verdict_display}"
        echo "**Confidence**: ${confidence}"
        echo "**Reviewed at**: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo "**Commit**: ${GIT_COMMIT:-unknown}"
        echo "**Model**: ${AI_MODEL}"
        echo ""
        echo "## Review Details"
        echo ""
        echo "${raw_content}"
    } > "${SHAREDDIR}/review_report.md"
}

# Generate an error report when the review process fails.
# Arguments:
#   $1 - Error message.
function agent_generate_error_report() {
    local error_message="${1:-Unknown error}"
    local jira_label="${JIRA_ISSUE:-Patch Review}"

    {
        echo "# AI Code Review: ${jira_label} — ERROR"
        echo ""
        echo "## Review Summary"
        echo "**Verdict**: REQUEST CHANGES"
        echo "**Confidence**: LOW"
        echo "**Reviewed at**: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        echo "**Commit**: ${GIT_COMMIT:-unknown}"
        echo "**Model**: ${AI_MODEL}"
        echo ""
        echo "## Error"
        echo "The AI code review process encountered an error and could not complete:"
        echo ""
        echo "${error_message}"
        echo ""
        echo "## Recommendation"
        echo "**REQUEST CHANGES** — The automated review could not be completed. Manual review is required."
    } > "${SHAREDDIR}/review_report.md"
}

