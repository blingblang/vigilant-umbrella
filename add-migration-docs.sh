#!/bin/bash

echo "Adding migration documentation to issues..."

# Repository and issue number pairs
declare -A REPO_ISSUES=(
    ["vigilant-umbrella"]="1"
    ["psychic-tribble"]="9"
    ["atlas-fluvial"]="9"
    ["studious-engine"]="9"
    ["congenial-bassoon"]="42"
    ["solid-adventure"]="9"
    ["automatic-octo-tribble"]="9"
    ["joyfulagents"]="10"
    ["effective-garbanzo"]="10"
    ["super-spork"]="1"
    ["reimagined-telegram"]="8"
)

for REPO in "${!REPO_ISSUES[@]}"; do
    ISSUE_NUM="${REPO_ISSUES[$REPO]}"
    echo "Adding docs to blingblang/$REPO issue #$ISSUE_NUM"

    # Add compact migration instructions
    gh issue comment "$ISSUE_NUM" --repo "blingblang/$REPO" --body "## Quick Migration Instructions

### Step 1: Configure Site for Central Monitoring
Run this on your server hosting this service:

\`\`\`bash
# Allow central monitor to scrape metrics
ufw allow from 159.89.243.148 to any port 9100

# Keep node-exporter running but remove prometheus/grafana
docker-compose stop prometheus grafana alertmanager
docker volume rm ${REPO}_prometheus_data ${REPO}_grafana_data || true
\`\`\`

### Step 2: Register with Central Monitoring
Contact me or run the add-remote-site.sh script with:
- Site name: $REPO
- Site IP: [your-server-ip]
- Node exporter port: 9100

### Step 3: Clean Up Repository
Remove from docker-compose.yml:
- prometheus service
- grafana service
- alertmanager service
- monitoring volumes

Keep:
- node-exporter service
- application metrics endpoints

### Central Monitoring Access:
- Grafana: http://159.89.243.148:3000
- Prometheus: http://159.89.243.148:9090"

    sleep 1
done

echo "✅ Documentation added to all issues!"