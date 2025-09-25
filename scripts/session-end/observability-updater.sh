#!/bin/bash

# Observability Updater - Updates monitoring configurations based on session changes
# Tool-agnostic implementation for observability maintenance

set -e

# Configuration
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
CHANGES_JSON="${1:-}"
PROMETHEUS_DIR="$PROJECT_ROOT/prometheus"
GRAFANA_DIR="$PROJECT_ROOT/grafana"
ALERTMANAGER_DIR="$PROJECT_ROOT/alertmanager"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to update Prometheus rules
update_prometheus_rules() {
    local changes="$1"

    echo -e "${BLUE}Checking Prometheus rules...${NC}"

    # Check if new services were added
    local new_services=$(echo "$changes" | jq -r '.categories.terraform' 2>/dev/null)

    if [ "$new_services" -gt 0 ]; then
        echo "Detected Terraform changes - updating service discovery"

        # Update prometheus rules for new resources
        local rules_file="$PROMETHEUS_DIR/rules/auto_generated.yml"
        mkdir -p "$(dirname "$rules_file")"

        cat > "$rules_file" <<EOF
# Auto-generated Prometheus rules
# Created by session-end automation at $(date -u +"%Y-%m-%dT%H:%M:%SZ")

groups:
  - name: auto_generated_alerts
    interval: 30s
    rules:
      # Service availability alerts
      - alert: ServiceDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
          auto_generated: "true"
        annotations:
          summary: "Service {{ \$labels.instance }} is down"
          description: "{{ \$labels.instance }} has been down for more than 5 minutes"

      # High CPU usage alert
      - alert: HighCPUUsage
        expr: rate(process_cpu_seconds_total[5m]) > 0.8
        for: 10m
        labels:
          severity: warning
          auto_generated: "true"
        annotations:
          summary: "High CPU usage on {{ \$labels.instance }}"
          description: "CPU usage is above 80% for more than 10 minutes"

      # Disk space alert
      - alert: LowDiskSpace
        expr: node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs|squashfs|vfat"} / node_filesystem_size_bytes < 0.1
        for: 5m
        labels:
          severity: warning
          auto_generated: "true"
        annotations:
          summary: "Low disk space on {{ \$labels.instance }}"
          description: "Less than 10% disk space remaining"
EOF

        echo -e "${GREEN}Created/Updated Prometheus rules${NC}"
    fi
}

# Function to update Grafana dashboards
update_grafana_dashboards() {
    local changes="$1"

    echo -e "${BLUE}Checking Grafana dashboards...${NC}"

    # Check for monitoring-related changes
    local mon_changes=$(echo "$changes" | jq -r '.categories.monitoring' 2>/dev/null)

    if [ "$mon_changes" -gt 0 ]; then
        echo "Detected monitoring changes - updating dashboards"

        local dashboard_file="$GRAFANA_DIR/dashboards/auto_session_overview.json"
        mkdir -p "$(dirname "$dashboard_file")"

        cat > "$dashboard_file" <<'EOF'
{
  "dashboard": {
    "id": null,
    "uid": "auto-session-overview",
    "title": "Session Changes Overview",
    "tags": ["auto-generated", "session"],
    "timezone": "browser",
    "schemaVersion": 30,
    "version": 1,
    "refresh": "30s",
    "panels": [
      {
        "id": 1,
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "type": "graph",
        "title": "Service Availability",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "up",
            "legendFormat": "{{instance}}",
            "refId": "A"
          }
        ]
      },
      {
        "id": 2,
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "type": "stat",
        "title": "Active Alerts",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "ALERTS{alertstate=\"firing\"}",
            "refId": "A"
          }
        ]
      },
      {
        "id": 3,
        "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
        "type": "logs",
        "title": "Recent Changes Log",
        "datasource": "Loki",
        "targets": [
          {
            "expr": "{job=\"session-automation\"}",
            "refId": "A"
          }
        ]
      }
    ]
  },
  "overwrite": true
}
EOF

        echo -e "${GREEN}Created/Updated Grafana dashboard${NC}"
    fi
}

# Function to update AlertManager configuration
update_alertmanager_config() {
    local changes="$1"

    echo -e "${BLUE}Checking AlertManager configuration...${NC}"

    # Check for critical changes
    local critical=$(echo "$changes" | jq -r '.critical.critical' 2>/dev/null)

    if [ "$critical" == "true" ]; then
        echo -e "${YELLOW}Critical changes detected - updating alert routing${NC}"

        # Add high-priority routing for critical changes
        local route_file="$ALERTMANAGER_DIR/routes_auto.yml"
        mkdir -p "$(dirname "$route_file")"

        cat > "$route_file" <<EOF
# Auto-generated AlertManager routes
# Created by session-end automation at $(date -u +"%Y-%m-%dT%H:%M:%SZ")

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'
  routes:
    # Critical alerts from session changes
    - match:
        severity: critical
        auto_generated: "true"
      receiver: 'critical-receiver'
      group_wait: 0s
      repeat_interval: 5m

    # Warning alerts
    - match:
        severity: warning
        auto_generated: "true"
      receiver: 'warning-receiver'
      group_wait: 30s
      repeat_interval: 30m

receivers:
  - name: 'default-receiver'
  - name: 'critical-receiver'
  - name: 'warning-receiver'

# Note: Actual receiver configurations should be added based on your notification setup
EOF

        echo -e "${GREEN}Updated AlertManager routes${NC}"
    fi
}

# Function to update logging configuration
update_logging_config() {
    local changes="$1"

    echo -e "${BLUE}Checking logging configuration...${NC}"

    # Check for script changes that might need additional logging
    local script_changes=$(echo "$changes" | jq -r '.categories.scripts' 2>/dev/null)

    if [ "$script_changes" -gt 0 ]; then
        echo "Detected script changes - updating logging configuration"

        # Create logging configuration for session automation
        local log_config="$PROJECT_ROOT/.session-automation/logging.conf"
        mkdir -p "$(dirname "$log_config")"

        cat > "$log_config" <<EOF
# Logging configuration for session-end automation
# Generated at $(date -u +"%Y-%m-%dT%H:%M:%SZ")

[loggers]
log_level = INFO
log_file = /var/log/session-automation.log
log_format = %(asctime)s - %(name)s - %(levelname)s - %(message)s

[handlers]
console = StreamHandler
file = FileHandler

[formatters]
standard = %(asctime)s - %(name)s - %(levelname)s - %(message)s
detailed = %(asctime)s - %(name)s - %(levelname)s - %(filename)s:%(lineno)d - %(message)s

# Components to log
[components]
test_updater = INFO
observability_updater = INFO
docs_updater = INFO
session_detector = DEBUG
EOF

        echo -e "${GREEN}Created logging configuration${NC}"
    fi
}

# Function to validate observability configs
validate_configs() {
    local errors=0

    echo -e "${BLUE}Validating observability configurations...${NC}"

    # Validate Prometheus config
    if [ -f "$PROMETHEUS_DIR/prometheus.yml" ]; then
        if ! docker run --rm -v "$PROMETHEUS_DIR":/prometheus prom/prometheus:latest promtool check config /prometheus/prometheus.yml 2>/dev/null; then
            echo -e "${YELLOW}Warning: Prometheus config validation failed${NC}"
            ((errors++))
        fi
    fi

    # Validate AlertManager config
    if [ -f "$ALERTMANAGER_DIR/alertmanager.yml" ]; then
        if ! docker run --rm -v "$ALERTMANAGER_DIR":/alertmanager prom/alertmanager:latest amtool check-config /alertmanager/alertmanager.yml 2>/dev/null; then
            echo -e "${YELLOW}Warning: AlertManager config validation failed${NC}"
            ((errors++))
        fi
    fi

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}All observability configurations valid${NC}"
        return 0
    else
        echo -e "${YELLOW}Some configurations need review${NC}"
        return 1
    fi
}

# Main execution
main() {
    echo -e "${GREEN}Observability Updater Starting${NC}"

    if [ -z "$CHANGES_JSON" ]; then
        echo -e "${RED}No changes JSON provided${NC}"
        exit 1
    fi

    # Update components
    update_prometheus_rules "$CHANGES_JSON"
    update_grafana_dashboards "$CHANGES_JSON"
    update_alertmanager_config "$CHANGES_JSON"
    update_logging_config "$CHANGES_JSON"

    # Validate configurations
    validate_configs

    echo -e "${GREEN}Observability updates completed${NC}"
}

main