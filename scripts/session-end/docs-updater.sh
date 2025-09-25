#!/bin/bash

# Documentation Updater - Updates documentation based on session changes
# Tool-agnostic implementation for documentation maintenance

set -e

# Configuration
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
CHANGES_JSON="${1:-}"
DOCS_DIR="$PROJECT_ROOT/docs"
CAPABILITIES_DIR="$DOCS_DIR/capabilities"
GUIDES_DIR="$DOCS_DIR/guides"
REPORTS_DIR="$DOCS_DIR/session-reports"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to update README
update_readme() {
    local changes="$1"
    local readme_file="$PROJECT_ROOT/README.md"

    if [ ! -f "$readme_file" ]; then
        echo -e "${YELLOW}README.md not found, creating basic template${NC}"

        cat > "$readme_file" <<EOF
# Project Documentation

This project includes automated session-end updates for tests, observability, and documentation.

## Recent Updates

Last automated update: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Components

- **Terraform**: Infrastructure as Code configurations
- **Monitoring**: Prometheus, Grafana, and AlertManager setup
- **Scripts**: Automation and management scripts
- **Documentation**: Technical guides and session reports

## Session Automation

This project uses automated session-end updates. See [Session Automation Guide](docs/guides/session-automation-guide.md) for details.

## Quick Start

\`\`\`bash
# Run session-end automation
./scripts/session-end/session-orchestrator.sh --mode interactive

# View recent session reports
ls -la docs/session-reports/
\`\`\`

## Documentation Structure

- \`docs/capabilities/\` - Capability specifications
- \`docs/guides/\` - Operational guides
- \`docs/session-reports/\` - Automated session reports
EOF
    fi

    # Update last modified timestamp
    if grep -q "Last automated update:" "$readme_file"; then
        sed -i "s/Last automated update:.*/Last automated update: $(date -u +"%Y-%m-%dT%H:%M:%SZ")/" "$readme_file"
    fi

    echo -e "${GREEN}Updated README.md${NC}"
}

# Function to create/update capability documentation
update_capability_docs() {
    local changes="$1"

    mkdir -p "$CAPABILITIES_DIR"

    local capability_file="$CAPABILITIES_DIR/session-end-automation.md"

    cat > "$capability_file" <<EOF
# Session-End Automation Capability

## Overview

This capability automates end-of-session workflows, ensuring that all code changes are properly reflected in tests, observability configurations, and documentation.

## Last Update

- **Timestamp**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- **Changes Processed**: $(echo "$changes" | jq '.stats.filesChanged' 2>/dev/null || echo "0")

## Components

### 1. Session Diff Detector
Monitors and categorizes changes in the git repository.

### 2. Test Updater
Automatically updates or creates test files based on code changes.

### 3. Observability Updater
Updates monitoring configurations, dashboards, and alerts.

### 4. Documentation Updater
Maintains project documentation and generates session reports.

## Usage

### Basic Command
\`\`\`bash
./scripts/session-end/session-orchestrator.sh
\`\`\`

### With Options
\`\`\`bash
# Dry run mode
./scripts/session-end/session-orchestrator.sh --dry-run

# Automatic mode (no prompts)
./scripts/session-end/session-orchestrator.sh --mode automatic

# Update specific components
./scripts/session-end/session-orchestrator.sh --components tests,documentation
\`\`\`

## Configuration

Create a \`.session-automation/config.yml\` file:

\`\`\`yaml
mode: interactive
components:
  - tests
  - observability
  - documentation
validation:
  require_tests_pass: true
  min_coverage: 80
rollback:
  strategy: atomic
  preserve_manual_changes: true
\`\`\`

## Workflow

1. **Detection**: Identifies changes in the repository
2. **Categorization**: Classifies changes by type and impact
3. **Planning**: Determines which updates are needed
4. **Execution**: Runs updates in parallel where possible
5. **Validation**: Ensures all changes meet quality standards
6. **Reporting**: Generates comprehensive session report

## Integration Points

- **Git Hooks**: Can be triggered by pre-commit or post-commit hooks
- **CI/CD**: Integrates with GitHub Actions, Jenkins, etc.
- **IDE**: Can be triggered from development environment
- **CLI**: Direct command-line invocation

## Recent Session Statistics

\`\`\`json
$(echo "$changes" | jq '{
  timestamp: .timestamp,
  files_changed: .stats.filesChanged,
  insertions: .stats.insertions,
  deletions: .stats.deletions,
  categories: .categories
}' 2>/dev/null || echo "{}")
\`\`\`
EOF

    echo -e "${GREEN}Updated capability documentation${NC}"
}

# Function to create/update operational guide
update_operational_guide() {
    local changes="$1"

    mkdir -p "$GUIDES_DIR"

    local guide_file="$GUIDES_DIR/session-automation-guide.md"

    cat > "$guide_file" <<EOF
# Session Automation Operational Guide

## Overview

This guide provides instructions for using and maintaining the session-end automation system.

Last Updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Quick Start

### Running Session Automation

1. **Interactive Mode** (recommended for beginners):
   \`\`\`bash
   ./scripts/session-end/session-orchestrator.sh --mode interactive
   \`\`\`

2. **Automatic Mode** (for CI/CD):
   \`\`\`bash
   ./scripts/session-end/session-orchestrator.sh --mode automatic
   \`\`\`

3. **Dry Run** (preview changes):
   \`\`\`bash
   ./scripts/session-end/session-orchestrator.sh --dry-run
   \`\`\`

## How It Works

### Change Detection

The system detects changes using git diff and categorizes them:
- **Terraform**: Infrastructure changes
- **Scripts**: Automation script modifications
- **Config**: Configuration file updates
- **Docs**: Documentation changes
- **Monitoring**: Observability configuration updates

### Update Process

1. **Test Updates**
   - Creates test files for new scripts
   - Updates existing test cases
   - Generates integration tests for significant changes

2. **Observability Updates**
   - Updates Prometheus rules
   - Creates/modifies Grafana dashboards
   - Adjusts AlertManager configurations
   - Updates logging settings

3. **Documentation Updates**
   - Updates README.md
   - Maintains capability documentation
   - Generates session reports
   - Updates operational guides

## Configuration

### Environment Variables

\`\`\`bash
export PROJECT_ROOT=/path/to/project
export SESSION_MODE=interactive
export COMPONENTS=tests,observability,documentation
export DRY_RUN=false
export REPORTS_DIR=/path/to/reports
\`\`\`

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| --mode | Session mode (interactive/automatic/dry-run) | interactive |
| --components | Components to update (comma-separated) | tests,observability,documentation |
| --dry-run | Run without making changes | false |
| --project-root | Project root directory | current directory |

## Monitoring

### Session Reports

Reports are generated in \`docs/session-reports/\` with:
- Summary of changes
- Actions taken
- Validation results
- Configuration used

### Logs

Check logs for debugging:
\`\`\`bash
# View recent session logs
tail -f ~/.session-automation/session.log

# Check for errors
grep ERROR ~/.session-automation/session.log
\`\`\`

## Troubleshooting

### Common Issues

1. **No changes detected**
   - Ensure you're in a git repository
   - Check for uncommitted changes with \`git status\`

2. **Validation failures**
   - Review generated test files
   - Check configuration syntax
   - Validate Terraform files manually

3. **Permission errors**
   - Ensure scripts are executable: \`chmod +x scripts/session-end/*.sh\`
   - Check directory write permissions

### Recovery

If automation fails:
1. Check the error message in the console
2. Review the session report for details
3. Manually revert changes if needed: \`git checkout -- .\`
4. Fix the issue and re-run

## Best Practices

1. **Regular Use**: Run after significant changes
2. **Review Reports**: Always check generated reports
3. **Validate Changes**: Use dry-run mode first for major updates
4. **Keep Updated**: Update automation scripts regularly
5. **Document Exceptions**: Note any manual overrides

## Advanced Usage

### Custom Hooks

Add pre/post hooks in \`.session-automation/hooks/\`:
\`\`\`bash
# .session-automation/hooks/pre-update.sh
#!/bin/bash
echo "Running pre-update checks..."

# .session-automation/hooks/post-update.sh
#!/bin/bash
echo "Post-update cleanup..."
\`\`\`

### Integration with CI/CD

Example GitHub Action:
\`\`\`yaml
name: Session Automation
on:
  push:
    branches: [main]
jobs:
  automate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Session Automation
        run: ./scripts/session-end/session-orchestrator.sh --mode automatic
\`\`\`

## Support

For issues or questions:
- Check documentation in \`docs/\`
- Review session reports
- Check script comments for details
EOF

    echo -e "${GREEN}Updated operational guide${NC}"
}

# Function to update API/technical documentation
update_technical_docs() {
    local changes="$1"

    # Check for API or significant code changes
    local tf_changes=$(echo "$changes" | jq -r '.categories.terraform' 2>/dev/null)
    local script_changes=$(echo "$changes" | jq -r '.categories.scripts' 2>/dev/null)

    if [ "$tf_changes" -gt 0 ] || [ "$script_changes" -gt 0 ]; then
        echo -e "${BLUE}Updating technical documentation...${NC}"

        local tech_doc="$DOCS_DIR/technical-reference.md"

        cat > "$tech_doc" <<EOF
# Technical Reference

Last Updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Project Structure

\`\`\`
.
├── scripts/
│   └── session-end/          # Session automation scripts
│       ├── session-orchestrator.sh
│       ├── session-diff-detector.sh
│       ├── test-updater.sh
│       ├── observability-updater.sh
│       └── docs-updater.sh
├── terraform/                # Infrastructure configurations
├── prometheus/               # Prometheus monitoring
├── grafana/                 # Grafana dashboards
├── alertmanager/            # Alert management
└── docs/                    # Documentation
    ├── capabilities/        # Capability specifications
    ├── guides/             # Operational guides
    └── session-reports/    # Automated reports
\`\`\`

## Script Reference

### session-orchestrator.sh
Main controller for session-end automation.

**Usage**: \`./session-orchestrator.sh [OPTIONS]\`

### session-diff-detector.sh
Detects and categorizes repository changes.

**Output**: JSON with change details

### test-updater.sh
Updates test files based on code changes.

**Input**: Changes JSON from diff detector

### observability-updater.sh
Updates monitoring configurations.

**Components Updated**:
- Prometheus rules
- Grafana dashboards
- AlertManager routes
- Logging configuration

### docs-updater.sh
Maintains project documentation.

**Documents Updated**:
- README.md
- Capability specifications
- Operational guides
- Technical references

## Change Categories

| Category | File Patterns | Impact |
|----------|--------------|--------|
| terraform | *.tf, *.tfvars | Infrastructure |
| scripts | *.sh, *.bat | Automation |
| config | *.yml, *.json | Configuration |
| docs | *.md, *.txt | Documentation |
| monitoring | prometheus/*, grafana/* | Observability |

## Validation Rules

- **Tests**: Must pass before updates are committed
- **Terraform**: Must validate successfully
- **YAML**: Must be valid syntax
- **JSON**: Must be well-formed
- **Scripts**: Must have executable permissions

## Recent Changes Summary

$(echo "$changes" | jq . 2>/dev/null || echo "No recent changes")
EOF

        echo -e "${GREEN}Updated technical documentation${NC}"
    fi
}

# Main execution
main() {
    echo -e "${GREEN}Documentation Updater Starting${NC}"

    if [ -z "$CHANGES_JSON" ]; then
        echo -e "${RED}No changes JSON provided${NC}"
        exit 1
    fi

    # Create documentation directories
    mkdir -p "$DOCS_DIR" "$CAPABILITIES_DIR" "$GUIDES_DIR" "$REPORTS_DIR"

    # Update various documentation components
    update_readme "$CHANGES_JSON"
    update_capability_docs "$CHANGES_JSON"
    update_operational_guide "$CHANGES_JSON"
    update_technical_docs "$CHANGES_JSON"

    # Create index file if it doesn't exist
    if [ ! -f "$DOCS_DIR/index.md" ]; then
        cat > "$DOCS_DIR/index.md" <<EOF
# Documentation Index

## Guides
- [Session Automation Guide](guides/session-automation-guide.md)

## Capabilities
- [Session-End Automation](capabilities/session-end-automation.md)

## Technical
- [Technical Reference](technical-reference.md)

## Reports
- [Session Reports](session-reports/)

Last Updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF
    fi

    echo -e "${GREEN}Documentation updates completed${NC}"
}

main