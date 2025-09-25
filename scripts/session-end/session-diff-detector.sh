#!/bin/bash

# Session Diff Detector - Detects changes in the current git session
# Tool-agnostic implementation for session-end automation

set -e

# Configuration
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to get current git metadata
get_git_metadata() {
    local branch=$(git branch --show-current 2>/dev/null || echo "detached")
    local commit=$(git rev-parse HEAD 2>/dev/null || echo "none")
    local author=$(git config user.name 2>/dev/null || echo "unknown")

    echo "{\"branch\":\"$branch\",\"commit\":\"$commit\",\"author\":\"$author\"}"
}

# Function to get file changes
get_file_changes() {
    local modified=$(git diff --name-only 2>/dev/null | wc -l)
    local added=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
    local deleted=$(git diff --name-only --diff-filter=D 2>/dev/null | wc -l)
    local staged=$(git diff --cached --name-only 2>/dev/null | wc -l)

    echo "{\"modified\":$modified,\"added\":$added,\"deleted\":$deleted,\"staged\":$staged}"
}

# Function to categorize changes
categorize_changes() {
    local categories="{\"terraform\":0,\"scripts\":0,\"config\":0,\"docs\":0,\"monitoring\":0}"

    # Check Terraform changes
    local tf_changes=$(git diff --name-only 2>/dev/null | grep -E "\.tf$|\.tfvars$" | wc -l)

    # Check script changes
    local script_changes=$(git diff --name-only 2>/dev/null | grep -E "\.sh$|\.bat$|\.ps1$" | wc -l)

    # Check config changes
    local config_changes=$(git diff --name-only 2>/dev/null | grep -E "\.yml$|\.yaml$|\.json$|\.env" | wc -l)

    # Check documentation changes
    local doc_changes=$(git diff --name-only 2>/dev/null | grep -E "\.md$|\.txt$" | wc -l)

    # Check monitoring config changes
    local mon_changes=$(git diff --name-only 2>/dev/null | grep -E "prometheus/|grafana/|alertmanager/" | wc -l)

    echo "{\"terraform\":$tf_changes,\"scripts\":$script_changes,\"config\":$config_changes,\"docs\":$doc_changes,\"monitoring\":$mon_changes}"
}

# Function to get change statistics
get_change_stats() {
    local stats=$(git diff --stat 2>/dev/null | tail -1)
    local insertions=$(echo "$stats" | grep -oE "[0-9]+ insertion" | grep -oE "[0-9]+" || echo "0")
    local deletions=$(echo "$stats" | grep -oE "[0-9]+ deletion" | grep -oE "[0-9]+" || echo "0")

    echo "{\"insertions\":$insertions,\"deletions\":$deletions}"
}

# Function to detect critical changes
detect_critical_changes() {
    local critical=false

    # Check for security-related changes
    if git diff --name-only 2>/dev/null | grep -qE "\.env|secrets|password|token|key"; then
        critical=true
    fi

    # Check for production terraform changes
    if git diff --name-only 2>/dev/null | grep -qE "terraform/.*prod.*\.tf"; then
        critical=true
    fi

    echo "{\"critical\":$critical}"
}

# Main execution
main() {
    cd "$PROJECT_ROOT"

    # Check if in git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "{\"error\":\"Not in a git repository\"}"
        exit 1
    fi

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local metadata=$(get_git_metadata)
    local changes=$(get_file_changes)
    local categories=$(categorize_changes)
    local stats=$(get_change_stats)
    local critical=$(detect_critical_changes)

    if [ "$OUTPUT_FORMAT" == "json" ]; then
        cat <<EOF
{
  "timestamp": "$timestamp",
  "metadata": $metadata,
  "changes": $changes,
  "categories": $categories,
  "stats": $stats,
  "critical": $critical
}
EOF
    else
        echo -e "${GREEN}Session Diff Detection Report${NC}"
        echo -e "${GREEN}=============================${NC}"
        echo "Timestamp: $timestamp"
        echo ""
        echo -e "${YELLOW}Metadata:${NC}"
        echo "$metadata" | jq .
        echo ""
        echo -e "${YELLOW}Changes:${NC}"
        echo "$changes" | jq .
        echo ""
        echo -e "${YELLOW}Categories:${NC}"
        echo "$categories" | jq .
        echo ""
        echo -e "${YELLOW}Statistics:${NC}"
        echo "$stats" | jq .
        echo ""
        echo -e "${YELLOW}Critical Changes:${NC}"
        echo "$critical" | jq .
    fi
}

# Run main function
main "$@"