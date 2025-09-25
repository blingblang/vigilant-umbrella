#!/bin/bash

# Session-End Automation Entry Point
# Main script to run session-end automation for the project

set -e

# Script configuration
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
SESSION_SCRIPTS_DIR="$PROJECT_ROOT/scripts/session-end"

# Default configuration
DEFAULT_MODE="interactive"
DEFAULT_COMPONENTS="tests,observability,documentation"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print banner
print_banner() {
    cat <<'EOF'

 ╔═══════════════════════════════════════════╗
 ║     SESSION-END AUTOMATION SYSTEM         ║
 ║     Tool-Agnostic Implementation          ║
 ╚═══════════════════════════════════════════╝

EOF
}

# Function to check if orchestrator exists
check_orchestrator() {
    if [ ! -f "$SESSION_SCRIPTS_DIR/session-orchestrator.sh" ]; then
        echo -e "${YELLOW}Session automation scripts not found!${NC}"
        echo "Expected location: $SESSION_SCRIPTS_DIR"
        echo ""
        echo "Please ensure the following scripts are present:"
        echo "  - session-orchestrator.sh"
        echo "  - session-diff-detector.sh"
        echo "  - test-updater.sh"
        echo "  - observability-updater.sh"
        echo "  - docs-updater.sh"
        echo "  - session-utils.sh"
        exit 1
    fi
}

# Function to make scripts executable
ensure_executable() {
    echo -e "${BLUE}Ensuring scripts are executable...${NC}"
    chmod +x "$SESSION_SCRIPTS_DIR"/*.sh 2>/dev/null || true
}

# Function to show help
show_help() {
    cat <<EOF

Usage: $0 [OPTIONS]

Run session-end automation to update tests, observability, and documentation
based on recent changes in the repository.

Options:
  --mode MODE           Set session mode (interactive|automatic|dry-run)
                       Default: $DEFAULT_MODE

  --components LIST     Comma-separated list of components to update
                       Options: tests,observability,documentation
                       Default: $DEFAULT_COMPONENTS

  --dry-run            Run in dry-run mode without making changes

  --quick              Quick mode - skip confirmations

  --status             Show current automation status

  --history            Show recent session reports

  --help               Show this help message

Examples:
  # Interactive mode (default)
  $0

  # Automatic mode (no prompts)
  $0 --mode automatic

  # Dry run to preview changes
  $0 --dry-run

  # Update only tests and documentation
  $0 --components tests,documentation

  # View recent session reports
  $0 --history

Environment Variables:
  SESSION_MODE         Override default mode
  COMPONENTS          Override default components
  PROJECT_ROOT        Override project root directory

For more information, see:
  docs/guides/session-automation-guide.md

EOF
}

# Function to show status
show_status() {
    echo -e "${BLUE}Session Automation Status${NC}"
    echo "=========================="
    echo ""

    # Check git status
    echo "Repository Status:"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "  Branch: $(git branch --show-current)"
        echo "  Changes: $(git status --porcelain | wc -l) files"
    else
        echo "  Not in a git repository"
    fi
    echo ""

    # Check script status
    echo "Scripts Status:"
    for script in session-orchestrator session-diff-detector test-updater observability-updater docs-updater session-utils; do
        if [ -f "$SESSION_SCRIPTS_DIR/$script.sh" ]; then
            echo "  ✓ $script.sh"
        else
            echo "  ✗ $script.sh (missing)"
        fi
    done
    echo ""

    # Check recent reports
    echo "Recent Reports:"
    if [ -d "$PROJECT_ROOT/docs/session-reports" ]; then
        local count=$(ls -1 "$PROJECT_ROOT/docs/session-reports" 2>/dev/null | wc -l)
        echo "  Found $count session reports"
        if [ $count -gt 0 ]; then
            echo "  Latest: $(ls -t "$PROJECT_ROOT/docs/session-reports" | head -1)"
        fi
    else
        echo "  No reports directory found"
    fi
}

# Function to show history
show_history() {
    echo -e "${BLUE}Session Report History${NC}"
    echo "======================"
    echo ""

    local reports_dir="$PROJECT_ROOT/docs/session-reports"

    if [ ! -d "$reports_dir" ]; then
        echo "No reports directory found at: $reports_dir"
        return
    fi

    local reports=$(ls -t "$reports_dir" 2>/dev/null)

    if [ -z "$reports" ]; then
        echo "No session reports found"
        return
    fi

    echo "Recent session reports:"
    echo ""

    local count=0
    for report in $reports; do
        if [ $count -ge 10 ]; then
            break
        fi

        local timestamp=$(echo "$report" | grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}-[0-9]{2}-[0-9]{2}")
        local status=$(grep "Status:" "$reports_dir/$report" 2>/dev/null | cut -d: -f2 | tr -d ' ')

        printf "  %-40s %s\n" "$report" "[$status]"
        ((count++))
    done

    echo ""
    echo "To view a report: cat $reports_dir/<report-name>"
}

# Main execution
main() {
    print_banner

    # Parse command line arguments
    local mode=""
    local components=""
    local dry_run=""
    local quick_mode=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode)
                mode="$2"
                shift 2
                ;;
            --components)
                components="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="--dry-run"
                shift
                ;;
            --quick)
                quick_mode="true"
                mode="automatic"
                shift
                ;;
            --status)
                show_status
                exit 0
                ;;
            --history)
                show_history
                exit 0
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Check orchestrator exists
    check_orchestrator

    # Ensure scripts are executable
    ensure_executable

    # Set defaults
    mode="${mode:-${SESSION_MODE:-$DEFAULT_MODE}}"
    components="${components:-${COMPONENTS:-$DEFAULT_COMPONENTS}}"

    # Build command
    local cmd="$SESSION_SCRIPTS_DIR/session-orchestrator.sh"
    cmd="$cmd --mode $mode"
    cmd="$cmd --components $components"
    cmd="$cmd --project-root $PROJECT_ROOT"

    if [ -n "$dry_run" ]; then
        cmd="$cmd $dry_run"
    fi

    # Show what we're about to do
    if [ "$quick_mode" != "true" ]; then
        echo -e "${GREEN}Configuration:${NC}"
        echo "  Mode: $mode"
        echo "  Components: $components"
        echo "  Project: $PROJECT_ROOT"
        if [ -n "$dry_run" ]; then
            echo "  Dry Run: Yes"
        fi
        echo ""
    fi

    # Execute orchestrator
    echo -e "${BLUE}Starting session-end automation...${NC}"
    echo ""

    # Run the orchestrator
    exec "$SESSION_SCRIPTS_DIR/session-orchestrator.sh" \
        --mode "$mode" \
        --components "$components" \
        --project-root "$PROJECT_ROOT" \
        $dry_run
}

# Run main function
main "$@"