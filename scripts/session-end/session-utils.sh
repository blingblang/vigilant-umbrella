#!/bin/bash

# Session Utilities - Common functions for session-end automation
# Tool-agnostic utility library

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [ "${DEBUG:-false}" == "true" ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# File operation functions
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_debug "Created directory: $dir"
    fi
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_debug "Backed up $file to $backup"
    fi
}

# Git functions
is_git_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

get_git_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

has_uncommitted_changes() {
    ! git diff-index --quiet HEAD -- 2>/dev/null
}

get_current_branch() {
    git branch --show-current 2>/dev/null || echo "unknown"
}

# Validation functions
validate_json() {
    local json="$1"
    if command -v jq &> /dev/null; then
        echo "$json" | jq . >/dev/null 2>&1
        return $?
    else
        # Basic validation without jq
        echo "$json" | grep -q "^{.*}$"
        return $?
    fi
}

validate_yaml() {
    local file="$1"
    if command -v python3 &> /dev/null; then
        python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null
        return $?
    else
        # Basic validation
        grep -q "^---" "$file" || grep -q "^[a-zA-Z].*:" "$file"
        return $?
    fi
}

# Process functions
run_with_timeout() {
    local timeout="$1"
    shift
    local command="$@"

    timeout "$timeout" bash -c "$command"
    local exit_code=$?

    if [ $exit_code -eq 124 ]; then
        log_error "Command timed out after ${timeout} seconds"
        return 1
    fi

    return $exit_code
}

# Confirmation functions
confirm_action() {
    local message="${1:-Continue?}"
    local default="${2:-n}"

    if [ "$default" == "y" ]; then
        local prompt="$message [Y/n]: "
        local default_response="y"
    else
        local prompt="$message [y/N]: "
        local default_response="n"
    fi

    read -p "$prompt" response
    response=${response:-$default_response}

    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# JSON manipulation functions
json_get() {
    local json="$1"
    local key="$2"

    if command -v jq &> /dev/null; then
        echo "$json" | jq -r ".$key"
    else
        # Basic extraction without jq
        echo "$json" | grep -oP "\"$key\":\s*\K[^,}]+"
    fi
}

json_set() {
    local json="$1"
    local key="$2"
    local value="$3"

    if command -v jq &> /dev/null; then
        echo "$json" | jq ".$key = $value"
    else
        # Basic replacement
        echo "$json" | sed "s/\"$key\":[^,}]*/\"$key\":$value/"
    fi
}

# Progress indication
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'

    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Error handling
trap_errors() {
    set -eE
    trap 'handle_error $? $LINENO' ERR
}

handle_error() {
    local exit_code=$1
    local line_number=$2
    log_error "Command failed with exit code $exit_code at line $line_number"

    # Cleanup if needed
    if [ -n "${CLEANUP_ON_ERROR:-}" ]; then
        eval "$CLEANUP_ON_ERROR"
    fi

    exit $exit_code
}

# Summary generation
generate_summary() {
    local start_time="$1"
    local end_time="$2"
    local status="$3"

    local duration=$((end_time - start_time))

    cat <<EOF

========================================
           SESSION SUMMARY
========================================
Status:   $status
Duration: ${duration} seconds
Time:     $(date)
========================================
EOF
}

# Check for required tools
check_required_tools() {
    local tools=("$@")
    local missing=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing+=("$tool")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        return 1
    fi

    return 0
}

# Export functions
export -f log_info log_success log_warning log_error log_debug
export -f ensure_directory backup_file
export -f is_git_repo get_git_root has_uncommitted_changes get_current_branch
export -f validate_json validate_yaml
export -f run_with_timeout confirm_action
export -f json_get json_set
export -f show_spinner trap_errors handle_error
export -f generate_summary check_required_tools