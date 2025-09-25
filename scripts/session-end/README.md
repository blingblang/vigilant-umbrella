# Session-End Automation Scripts

This directory contains the tool-agnostic session-end automation system that automatically updates tests, observability configurations, and documentation based on repository changes.

## Scripts Overview

| Script | Purpose |
|--------|---------|
| `session-orchestrator.sh` | Main controller that coordinates all automation |
| `session-diff-detector.sh` | Detects and categorizes repository changes |
| `test-updater.sh` | Creates and updates test files |
| `observability-updater.sh` | Updates monitoring configurations |
| `docs-updater.sh` | Maintains documentation |
| `session-utils.sh` | Common utility functions |

## Quick Start

From the project root:

```bash
# Run interactive session automation
./session-end.sh

# Dry run to preview changes
./session-end.sh --dry-run

# Automatic mode (no prompts)
./session-end.sh --mode automatic
```

## Features

- **Tool-Agnostic**: Works with any development stack
- **Multi-Component**: Updates tests, observability, and docs
- **Configurable**: YAML configuration and command-line options
- **Safe**: Dry-run mode and validation checks
- **Reporting**: Generates detailed session reports

## Configuration

Edit `.session-automation/config.yml` to customize behavior.

## Documentation

- [Capability Specification](../../docs/capabilities/session-end-automation.md)
- [Operational Guide](../../docs/guides/session-automation-guide.md)
- [Session Reports](../../docs/session-reports/)

## Requirements

- Git
- Bash 4.0+
- Optional: jq (for JSON formatting)
- Optional: Python 3 (for YAML validation)