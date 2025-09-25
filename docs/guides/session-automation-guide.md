# Session-End Automation Operational Guide

## Overview

This guide provides comprehensive instructions for using the session-end automation system to automatically update tests, observability configurations, and documentation based on repository changes.

## Quick Start

### Installation

1. **Verify Scripts Are Present**
   ```bash
   ls -la scripts/session-end/
   ```

2. **Make Scripts Executable**
   ```bash
   chmod +x session-end.sh
   chmod +x scripts/session-end/*.sh
   ```

3. **Run Your First Session**
   ```bash
   # Interactive mode (recommended for first use)
   ./session-end.sh

   # Or dry-run to see what would happen
   ./session-end.sh --dry-run
   ```

## Usage Modes

### Interactive Mode (Default)

Best for development and learning:
```bash
./session-end.sh --mode interactive
```
- Prompts for confirmation before changes
- Shows detailed progress
- Allows selective component updates

### Automatic Mode

Best for CI/CD and automation:
```bash
./session-end.sh --mode automatic
```
- No user prompts
- Proceeds with all configured updates
- Suitable for scripts and pipelines

### Dry-Run Mode

Best for testing and preview:
```bash
./session-end.sh --dry-run
```
- Shows what would be changed
- No actual modifications
- Safe for experimentation

### Quick Mode

Fast execution with minimal output:
```bash
./session-end.sh --quick
```
- Automatic mode
- Skips confirmations
- Minimal output

## Component Selection

### Update All Components (Default)
```bash
./session-end.sh
```

### Update Specific Components
```bash
# Only tests
./session-end.sh --components tests

# Tests and documentation
./session-end.sh --components tests,documentation

# Only observability
./session-end.sh --components observability
```

## Configuration

### Using Configuration File

Edit `.session-automation/config.yml`:
```yaml
mode: interactive
components:
  - tests
  - observability
  - documentation
validation:
  require_tests_pass: true
```

### Using Environment Variables

```bash
export SESSION_MODE=automatic
export COMPONENTS=tests,documentation
export DRY_RUN=true
./session-end.sh
```

### Command-Line Override

Command-line arguments override all other settings:
```bash
./session-end.sh --mode automatic --components tests
```

## Workflow Examples

### Developer Workflow

1. **Make Changes**
   ```bash
   # Edit your files
   vim terraform/main.tf
   vim scripts/deploy.sh
   ```

2. **Run Session Automation**
   ```bash
   ./session-end.sh --mode interactive
   ```

3. **Review Changes**
   ```bash
   # Check generated tests
   ls -la tests/

   # Review documentation updates
   cat docs/session-reports/latest.md
   ```

4. **Commit Everything**
   ```bash
   git add .
   git commit -m "feat: update infrastructure with automated tests"
   ```

### CI/CD Workflow

Add to your pipeline:
```yaml
# GitHub Actions example
- name: Run Session Automation
  run: |
    ./session-end.sh --mode automatic
    git add .
    git commit -m "chore: automated session updates" || true
```

### Pre-Commit Hook

Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash
./session-end.sh --quick --components tests
```

## Understanding Output

### Session Reports

Location: `docs/session-reports/session-report-YYYY-MM-DDTHH-MM-SS.md`

Contains:
- Summary of changes
- Actions taken
- Validation results
- Configuration used

### Console Output

```
[INFO] Starting session-end automation...
[INFO] Detecting changes...
[SUCCESS] Found 5 file changes
[INFO] Updating tests...
[SUCCESS] Created 3 test files
[INFO] Updating documentation...
[SUCCESS] Documentation updated
[SUCCESS] Session-end automation completed
```

### Status Indicators

- `[INFO]` - Informational message
- `[SUCCESS]` - Operation succeeded
- `[WARNING]` - Non-critical issue
- `[ERROR]` - Operation failed

## Component Details

### Test Updates

What gets updated:
- Creates test files for new scripts
- Updates existing test cases
- Generates integration tests
- Creates Terraform validation tests

Example output:
```bash
tests/
├── scripts/
│   └── deploy.test.sh
├── integration/
│   └── session-end.test.sh
└── terraform/
    └── validate.sh
```

### Observability Updates

What gets updated:
- Prometheus alerting rules
- Grafana dashboards
- AlertManager routing
- Logging configurations

Example output:
```bash
prometheus/rules/auto_generated.yml
grafana/dashboards/auto_session_overview.json
alertmanager/routes_auto.yml
```

### Documentation Updates

What gets updated:
- README.md timestamp
- Capability specifications
- Operational guides
- Technical references
- Session reports

Example output:
```bash
docs/
├── capabilities/session-end-automation.md
├── guides/session-automation-guide.md
├── technical-reference.md
└── session-reports/session-report-*.md
```

## Validation

### Automatic Validation

The system automatically validates:
- Test execution
- Terraform configuration
- YAML/JSON syntax
- Script permissions

### Manual Validation

Check results manually:
```bash
# Run tests
./manage.sh test

# Validate Terraform
terraform validate -chdir=terraform/

# Check monitoring configs
docker-compose config
```

## Troubleshooting

### Common Issues

#### No Changes Detected

```bash
# Check git status
git status

# Force change detection
touch test.txt
./session-end.sh
```

#### Permission Denied

```bash
# Fix script permissions
chmod +x session-end.sh
chmod +x scripts/session-end/*.sh
```

#### Validation Failures

```bash
# Run with debug output
export DEBUG=true
./session-end.sh

# Check specific component
./session-end.sh --components tests --dry-run
```

### Debug Mode

Enable detailed output:
```bash
export DEBUG=true
./session-end.sh
```

### Check Status

View system status:
```bash
./session-end.sh --status
```

### View History

See recent runs:
```bash
./session-end.sh --history
```

## Best Practices

### Daily Development

1. Run after significant changes
2. Use interactive mode for control
3. Review reports before committing
4. Keep configuration updated

### Before Commits

1. Run with all components
2. Ensure validation passes
3. Review generated artifacts
4. Include in commit

### Production Deployments

1. Use automatic mode
2. Enable all validations
3. Configure rollback strategy
4. Monitor execution logs

## Advanced Usage

### Custom Hooks

Add scripts to `.session-automation/hooks/`:

**pre-update.sh**:
```bash
#!/bin/bash
echo "Preparing for updates..."
# Custom preparation logic
```

**post-update.sh**:
```bash
#!/bin/bash
echo "Cleaning up..."
# Custom cleanup logic
```

### Exclude Patterns

Edit `.session-automation/config.yml`:
```yaml
exclude:
  paths:
    - vendor/
    - node_modules/
  patterns:
    - "*.tmp"
    - "*.backup"
```

### Parallel Execution

Configure for performance:
```yaml
performance:
  parallel_execution: true
  max_workers: 4
```

## Integration Examples

### GitHub Actions

`.github/workflows/session-automation.yml`:
```yaml
name: Session Automation
on:
  push:
    branches: [main]
jobs:
  automate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Automation
        run: ./session-end.sh --mode automatic
      - name: Commit Changes
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "chore: automated updates" || true
          git push
```

### Jenkins Pipeline

```groovy
stage('Session Automation') {
    steps {
        sh './session-end.sh --mode automatic'
        sh 'git add .'
        sh 'git commit -m "chore: automated updates" || true'
    }
}
```

### Git Hooks

`.git/hooks/post-merge`:
```bash
#!/bin/bash
./session-end.sh --quick --components documentation
```

## Maintenance

### Regular Tasks

- **Weekly**: Review session reports
- **Monthly**: Update configuration
- **Quarterly**: Review automation patterns

### Updates

Check for updates to scripts:
```bash
# Compare with template repository
diff -r scripts/session-end/ /path/to/template/scripts/session-end/
```

### Cleanup

Remove old reports:
```bash
# Keep only last 30 days
find docs/session-reports -mtime +30 -delete
```

## FAQ

### Q: Can I undo changes made by automation?

Yes, use git to revert:
```bash
git checkout -- .
```

### Q: How do I skip automation for a commit?

Add to commit message:
```bash
git commit -m "fix: urgent fix [skip-automation]"
```

### Q: Can I run specific updaters directly?

Yes:
```bash
./scripts/session-end/test-updater.sh "$(./scripts/session-end/session-diff-detector.sh)"
```

### Q: How do I add custom test templates?

Edit `scripts/session-end/test-updater.sh` and modify the template generation functions.

## Support

For help:
1. Check this guide
2. Review session reports
3. Enable debug mode
4. Check script comments