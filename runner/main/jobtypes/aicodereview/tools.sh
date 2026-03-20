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

# Tool implementations for the AI Code Review agent.
#
# Each tool function wraps a docker exec call into the WEBSERVER container
# to interact with the Moodle codebase. Tools enforce size limits to prevent
# excessive output from consuming memory or token budget.

# Maximum output size in bytes for any single tool call (64KB).
TOOL_MAX_OUTPUT_SIZE="${TOOL_MAX_OUTPUT_SIZE:-65536}"

# Base path to Moodle code inside the container.
CONTAINER_MOODLE_PATH="/var/www/html"

# Sanitise a path to prevent directory traversal attacks.
# Ensures the path stays within the Moodle codebase.
# Arguments:
#   $1 - The path to sanitise (relative to Moodle root).
# Returns:
#   The sanitised path (relative), or exits with error if invalid.
function tool_sanitise_path() {
    local path="${1:-}"

    # Remove any leading slash to make it relative.
    path="${path#/}"

    # Remove any leading "var/www/html/" prefix if the AI provides absolute container paths.
    path="${path#var/www/html/}"

    # Block directory traversal.
    if [[ "${path}" == *".."* ]]; then
        echo "ERROR: Directory traversal not allowed in path: ${path}"
        return 1
    fi

    echo "${path}"
}

# Read a file's contents from the Moodle codebase.
# Arguments (via JSON):
#   path       - File path relative to Moodle root.
#   start_line - (optional) Start line number (1-based).
#   end_line   - (optional) End line number (1-based).
function tool_read_file() {
    local path="${1:-}"
    local start_line="${2:-}"
    local end_line="${3:-}"

    path=$(tool_sanitise_path "${path}") || return 1

    if [[ -z "${path}" ]]; then
        echo "ERROR: path argument is required for READ_FILE."
        return 1
    fi

    local cmd
    if [[ -n "${start_line}" ]] && [[ -n "${end_line}" ]]; then
        # Use sed to extract line range.
        cmd="sed -n '${start_line},${end_line}p' '${CONTAINER_MOODLE_PATH}/${path}'"
    elif [[ -n "${start_line}" ]]; then
        cmd="sed -n '${start_line},\$p' '${CONTAINER_MOODLE_PATH}/${path}' | head -c ${TOOL_MAX_OUTPUT_SIZE}"
    else
        cmd="cat '${CONTAINER_MOODLE_PATH}/${path}' | head -c ${TOOL_MAX_OUTPUT_SIZE}"
    fi

    local output
    output=$(docker exec -u www-data "${WEBSERVER}" bash -c "${cmd}" 2>&1) || {
        echo "ERROR: Failed to read file: ${path}"
        echo "${output}"
        return 0  # Return 0 so the agent loop continues; the error message is the tool result.
    }

    # Truncate if too large.
    if [[ ${#output} -gt ${TOOL_MAX_OUTPUT_SIZE} ]]; then
        output="${output:0:${TOOL_MAX_OUTPUT_SIZE}}"
        output+=$'\n[OUTPUT TRUNCATED - file too large. Use start_line/end_line to read specific sections.]'
    fi

    echo "${output}"
}

# Search for a pattern in the Moodle codebase using grep.
# Arguments (via JSON):
#   pattern - The grep pattern to search for.
#   path    - (optional) Directory/file path to search in (relative to Moodle root).
#   flags   - (optional) Additional grep flags (default: -rn).
function tool_grep_search() {
    local pattern="${1:-}"
    local path="${2:-.}"
    local flags="${3:--rn}"

    path=$(tool_sanitise_path "${path}") || return 1

    if [[ -z "${pattern}" ]]; then
        echo "ERROR: pattern argument is required for GREP_SEARCH."
        return 1
    fi

    # Limit results to prevent excessive output.
    local max_matches=100
    local output
    output=$(docker exec -u www-data "${WEBSERVER}" \
        bash -c "grep ${flags} --include='*.php' --include='*.js' --include='*.mustache' --include='*.xml' --include='*.txt' --include='*.md' '${pattern}' '${CONTAINER_MOODLE_PATH}/${path}' 2>/dev/null | head -n ${max_matches}" 2>&1) || true

    # Strip the container path prefix for cleaner output.
    output=$(echo "${output}" | sed "s|${CONTAINER_MOODLE_PATH}/||g")

    if [[ -z "${output}" ]]; then
        echo "No matches found for pattern: ${pattern} in ${path}"
    else
        echo "${output}"
        local match_count
        match_count=$(echo "${output}" | wc -l)
        if [[ ${match_count} -ge ${max_matches} ]]; then
            echo "[Results limited to ${max_matches} matches. Refine your search for more specific results.]"
        fi
    fi
}

# List directory contents in the Moodle codebase.
# Arguments (via JSON):
#   path - Directory path relative to Moodle root.
function tool_list_dir() {
    local path="${1:-.}"

    path=$(tool_sanitise_path "${path}") || return 1

    local output
    output=$(docker exec -u www-data "${WEBSERVER}" \
        bash -c "ls -la '${CONTAINER_MOODLE_PATH}/${path}' 2>&1 | head -n 100") || {
        echo "ERROR: Failed to list directory: ${path}"
        return 0
    }

    echo "${output}"
}

# View git log for a specific file.
# Arguments (via JSON):
#   path  - File path relative to Moodle root.
#   count - (optional) Number of log entries (default: 10).
function tool_git_log() {
    local path="${1:-}"
    local count="${2:-10}"

    path=$(tool_sanitise_path "${path}") || return 1

    if [[ -z "${path}" ]]; then
        echo "ERROR: path argument is required for GIT_LOG."
        return 1
    fi

    local output
    output=$(docker exec -u www-data "${WEBSERVER}" \
        git log --oneline -"${count}" -- "${CONTAINER_MOODLE_PATH}/${path}" 2>&1) || {
        echo "ERROR: Failed to get git log for: ${path}"
        return 0
    }

    echo "${output}"
}

# Find files by name pattern in the Moodle codebase.
# Arguments (via JSON):
#   pattern - File name pattern (e.g., "*.php", "lib.php").
#   path    - (optional) Directory to search in (relative to Moodle root).
function tool_find_file() {
    local pattern="${1:-}"
    local path="${2:-.}"

    path=$(tool_sanitise_path "${path}") || return 1

    if [[ -z "${pattern}" ]]; then
        echo "ERROR: pattern argument is required for FIND_FILE."
        return 1
    fi

    local output
    output=$(docker exec -u www-data "${WEBSERVER}" \
        bash -c "find '${CONTAINER_MOODLE_PATH}/${path}' -name '${pattern}' -type f 2>/dev/null | head -n 50" 2>&1) || true

    # Strip the container path prefix.
    output=$(echo "${output}" | sed "s|${CONTAINER_MOODLE_PATH}/||g")

    if [[ -z "${output}" ]]; then
        echo "No files found matching pattern: ${pattern} in ${path}"
    else
        echo "${output}"
    fi
}

# Find where a PHP function is defined.
# Arguments (via JSON):
#   name - Function or method name to search for.
function tool_php_function() {
    local name="${1:-}"

    if [[ -z "${name}" ]]; then
        echo "ERROR: name argument is required for PHP_FUNCTION."
        return 1
    fi

    local output
    output=$(docker exec -u www-data "${WEBSERVER}" \
        bash -c "grep -rn 'function ${name}\s*(' '${CONTAINER_MOODLE_PATH}/' --include='*.php' 2>/dev/null | head -n 20" 2>&1) || true

    # Strip the container path prefix.
    output=$(echo "${output}" | sed "s|${CONTAINER_MOODLE_PATH}/||g")

    if [[ -z "${output}" ]]; then
        echo "No definition found for function: ${name}"
    else
        echo "${output}"
    fi
}

# View a specific git commit.
# Arguments (via JSON):
#   hash - The commit hash to show.
function tool_git_show() {
    local hash="${1:-}"

    if [[ -z "${hash}" ]]; then
        echo "ERROR: hash argument is required for GIT_SHOW."
        return 1
    fi

    # Sanitise: only allow hex characters.
    if [[ ! "${hash}" =~ ^[0-9a-fA-F]+$ ]]; then
        echo "ERROR: Invalid commit hash format: ${hash}"
        return 1
    fi

    local output
    output=$(docker exec -u www-data "${WEBSERVER}" \
        git show --stat -p "${hash}" 2>&1 | head -c "${TOOL_MAX_OUTPUT_SIZE}") || {
        echo "ERROR: Failed to show commit: ${hash}"
        return 0
    }

    echo "${output}"
}

# Dispatch a tool call based on tool name and JSON arguments.
# Arguments:
#   $1 - Tool name (e.g., READ_FILE, GREP_SEARCH).
#   $2 - JSON string of arguments.
# Returns:
#   Tool output on stdout.
function dispatch_tool() {
    local tool_name="${1:-}"
    local args_json="${2:-{}}"

    case "${tool_name}" in
        READ_FILE)
            local path start_line end_line
            path=$(echo "${args_json}" | jq -r '.path // empty')
            start_line=$(echo "${args_json}" | jq -r '.start_line // empty')
            end_line=$(echo "${args_json}" | jq -r '.end_line // empty')
            tool_read_file "${path}" "${start_line}" "${end_line}"
            ;;
        GREP_SEARCH)
            local pattern path flags
            pattern=$(echo "${args_json}" | jq -r '.pattern // empty')
            path=$(echo "${args_json}" | jq -r '.path // "."')
            flags=$(echo "${args_json}" | jq -r '.flags // "-rn"')
            tool_grep_search "${pattern}" "${path}" "${flags}"
            ;;
        LIST_DIR)
            local path
            path=$(echo "${args_json}" | jq -r '.path // "."')
            tool_list_dir "${path}"
            ;;
        GIT_LOG)
            local path count
            path=$(echo "${args_json}" | jq -r '.path // empty')
            count=$(echo "${args_json}" | jq -r '.count // "10"')
            tool_git_log "${path}" "${count}"
            ;;
        GIT_SHOW)
            local hash
            hash=$(echo "${args_json}" | jq -r '.hash // empty')
            tool_git_show "${hash}"
            ;;
        PHP_FUNCTION)
            local name
            name=$(echo "${args_json}" | jq -r '.name // empty')
            tool_php_function "${name}"
            ;;
        FIND_FILE)
            local pattern path
            pattern=$(echo "${args_json}" | jq -r '.pattern // empty')
            path=$(echo "${args_json}" | jq -r '.path // "."')
            tool_find_file "${pattern}" "${path}"
            ;;
        *)
            echo "ERROR: Unknown tool: ${tool_name}. Available tools: READ_FILE, GREP_SEARCH, LIST_DIR, GIT_LOG, GIT_SHOW, PHP_FUNCTION, FIND_FILE"
            ;;
    esac
}

