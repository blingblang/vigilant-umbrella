#!/bin/bash

# Session Orchestrator - Main controller for session-end automation
# Tool-agnostic implementation that coordinates all update operations

set -e

# Configuration defaults
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
SESSION_MODE="${SESSION_MODE:-interactive}"
COMPONENTS="${COMPONENTS:-tests,observability,documentation}"
DRY_RUN="${DRY_RUN:-false}"
REPORTS_DIR="${REPORTS_DIR:-$PROJECT_ROOT/docs/session-reports}"

# Import utilities
source "$SCRIPT_DIR/session-utils.sh" 2>/dev/null || true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print status
print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Function to print error
print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to print success
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check git
    if ! command -v git &> /dev/null; then
        print_error "git is not installed"
        return 1
    fi

    # Check if in git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        print_error "Not in a git repository"
        return 1
    fi

    # Check for jq (optional but recommended)
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed - JSON output will be unformatted"
    fi

    print_success "Prerequisites check passed"
    return 0
}

# Function to detect changes
detect_changes() {
    print_status "Detecting changes..."

    local diff_output=$("$SCRIPT_DIR/session-diff-detector.sh" 2>/dev/null)

    if [ $? -ne 0 ]; then
        print_error "Failed to detect changes"
        return 1
    fi

    echo "$diff_output"
    return 0
}

# Function to update tests
update_tests() {
    local changes_json="$1"

    if ! echo "$COMPONENTS" | grep -q "tests"; then
        return 0
    fi

    print_status "Updating tests..."

    if [ "$DRY_RUN" == "true" ]; then
        print_warning "DRY RUN: Would update tests based on changes"
        return 0
    fi

    # Check for test script
    if [ -f "$SCRIPT_DIR/test-updater.sh" ]; then
        "$SCRIPT_DIR/test-updater.sh" "$changes_json"
    else
        print_warning "Test updater not found, skipping test updates"
    fi

    return 0
}

# Function to update observability
update_observability() {
    local changes_json="$1"

    if ! echo "$COMPONENTS" | grep -q "observability"; then
        return 0
    fi

    print_status "Updating observability configurations..."

    if [ "$DRY_RUN" == "true" ]; then
        print_warning "DRY RUN: Would update observability configs"
        return 0
    fi

    # Check for observability updater
    if [ -f "$SCRIPT_DIR/observability-updater.sh" ]; then
        "$SCRIPT_DIR/observability-updater.sh" "$changes_json"
    else
        print_warning "Observability updater not found, skipping observability updates"
    fi

    return 0
}

# Function to update documentation
update_documentation() {
    local changes_json="$1"

    if ! echo "$COMPONENTS" | grep -q "documentation"; then
        return 0
    fi

    print_status "Updating documentation..."

    if [ "$DRY_RUN" == "true" ]; then
        print_warning "DRY RUN: Would update documentation"
        return 0
    fi

    # Check for docs updater
    if [ -f "$SCRIPT_DIR/docs-updater.sh" ]; then
        "$SCRIPT_DIR/docs-updater.sh" "$changes_json"
    else
        print_warning "Documentation updater not found, skipping documentation updates"
    fi

    return 0
}

# Function to validate updates
validate_updates() {
    print_status "Validating updates..."

    local validation_passed=true

    # Run tests if available
    if [ -f "$PROJECT_ROOT/manage.sh" ]; then
        print_status "Running validation checks..."
        if ! "$PROJECT_ROOT/manage.sh" test 2>/dev/null; then
            print_warning "Some tests failed"
            validation_passed=false
        fi
    fi

    # Check terraform if changes detected
    if [ -d "$PROJECT_ROOT/terraform" ]; then
        print_status "Validating Terraform configuration..."
        if ! terraform validate -chdir="$PROJECT_ROOT/terraform" 2>/dev/null; then
            print_warning "Terraform validation failed"
            validation_passed=false
        fi
    fi

    if [ "$validation_passed" == "true" ]; then
        print_success "All validations passed"
        return 0
    else
        print_warning "Some validations failed - review changes carefully"
        return 1
    fi
}

# Function to generate session report
generate_report() {
    local changes_json="$1"
    local start_time="$2"
    local end_time="$3"
    local status="$4"

    print_status "Generating session report..."

    # Create reports directory if not exists
    mkdir -p "$REPORTS_DIR"

    local report_file="$REPORTS_DIR/session-report-$(date -u +"%Y-%m-%dT%H-%M-%S").md"
    local duration=$((end_time - start_time))

    cat > "$report_file" <<EOF
# Session Automation Report

## Summary

- **Date**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- **Duration**: ${duration}s
- **Status**: $status
- **Mode**: $SESSION_MODE
- **Components**: $COMPONENTS

## Changes Detected

\`\`\`json
$changes_json
\`\`\`

## Actions Taken

- Tests Updated: $(echo "$COMPONENTS" | grep -q "tests" && echo "Yes" || echo "No")
- Observability Updated: $(echo "$COMPONENTS" | grep -q "observability" && echo "Yes" || echo "No")
- Documentation Updated: $(echo "$COMPONENTS" | grep -q "documentation" && echo "Yes" || echo "No")

## Configuration

\`\`\`bash
PROJECT_ROOT=$PROJECT_ROOT
SESSION_MODE=$SESSION_MODE
COMPONENTS=$COMPONENTS
DRY_RUN=$DRY_RUN
\`\`\`

## Validation Results

$(validate_updates && echo "All validations passed" || echo "Some validations failed")

---
Generated by Session-End Automation System
EOF

    print_success "Report generated: $report_file"
    return 0
}

# Function for interactive mode
interactive_mode() {
    local changes_json="$1"

    echo -e "\n${YELLOW}Interactive Mode${NC}"
    echo "Detected changes summary:"
    echo "$changes_json" | jq '.categories' 2>/dev/null || echo "$changes_json"

    echo -e "\nDo you want to proceed with updates? (y/n): "
    read -r response

    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        print_warning "Updates cancelled by user"
        return 1
    fi

    return 0
}

# Main execution function
main() {
    local start_time=$(date +%s)
    local status="SUCCESS"

    print_status "Starting session-end automation..."

    # Check prerequisites
    if ! check_prerequisites; then
        print_error "Prerequisites check failed"
        exit 1
    fi

    # Detect changes
    local changes_json=$(detect_changes)
    if [ $? -ne 0 ]; then
        print_error "Failed to detect changes"
        exit 1
    fi

    # Check if there are any changes
    local total_changes=$(echo "$changes_json" | jq '.changes.modified + .changes.added + .changes.deleted' 2>/dev/null || echo "0")

    if [ "$total_changes" -eq 0 ]; then
        print_warning "No changes detected, skipping updates"
        local end_time=$(date +%s)
        generate_report "$changes_json" "$start_time" "$end_time" "NO_CHANGES"
        exit 0
    fi

    # Interactive mode check
    if [ "$SESSION_MODE" == "interactive" ]; then
        if ! interactive_mode "$changes_json"; then
            local end_time=$(date +%s)
            generate_report "$changes_json" "$start_time" "$end_time" "CANCELLED"
            exit 0
        fi
    fi

    # Execute updates
    local update_errors=0

    update_tests "$changes_json" || ((update_errors++))
    update_observability "$changes_json" || ((update_errors++))
    update_documentation "$changes_json" || ((update_errors++))

    # Validate updates
    if [ "$DRY_RUN" != "true" ]; then
        if ! validate_updates; then
            status="VALIDATION_FAILED"
            print_warning "Validation failed - please review changes"
        fi
    fi

    if [ $update_errors -gt 0 ]; then
        status="PARTIAL_SUCCESS"
        print_warning "Some updates failed"
    fi

    # Generate report
    local end_time=$(date +%s)
    generate_report "$changes_json" "$start_time" "$end_time" "$status"

    # Final status
    if [ "$status" == "SUCCESS" ]; then
        print_success "Session-end automation completed successfully"
    else
        print_warning "Session-end automation completed with issues"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            SESSION_MODE="$2"
            shift 2
            ;;
        --components)
            COMPONENTS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --project-root)
            PROJECT_ROOT="$2"
            shift 2
            ;;
        --help)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --mode MODE           Set session mode (interactive|automatic|dry-run)
  --components LIST     Comma-separated list of components to update
  --dry-run            Run in dry-run mode without making changes
  --project-root PATH  Set project root directory
  --help               Show this help message

Components:
  tests              Update test files
  observability      Update monitoring configurations
  documentation      Update documentation files

Examples:
  $0 --mode automatic
  $0 --dry-run --components tests,documentation
  $0 --mode interactive --project-root /path/to/project

EOF
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main