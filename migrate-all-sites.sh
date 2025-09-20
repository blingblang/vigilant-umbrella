#!/bin/bash

set -e

# Central monitoring droplet
MONITORING_IP="159.89.243.148"

echo "Bulk Site Migration to Central Monitoring"
echo "=========================================="
echo ""
echo "This script will migrate multiple sites to central monitoring."
echo ""

# Define your sites here
# Format: "name,host,node_port,app_port,app_path,environment"
SITES=(
    # "site1,site1.example.com,9100,8080,/metrics,production"
    # "site2,10.132.0.2,9100,,,production"  # Private IP, no app metrics
    # "site3,site3.example.com,9100,3000,/api/metrics,staging"
)

# Or load from file
if [ -f "sites.txt" ]; then
    echo "Loading sites from sites.txt..."
    mapfile -t SITES < sites.txt
fi

if [ ${#SITES[@]} -eq 0 ]; then
    echo "No sites configured. Please either:"
    echo "1. Edit this script and add sites to the SITES array"
    echo "2. Create a sites.txt file with one site per line"
    echo ""
    echo "Format: name,host,node_port,app_port,app_path,environment"
    echo "Example: site1,site1.example.com,9100,8080,/metrics,production"
    exit 1
fi

echo "Found ${#SITES[@]} sites to migrate"
echo ""

# Create consolidated configuration
CONFIG_FILE="/tmp/migration-config-$(date +%Y%m%d-%H%M%S).yml"
echo "" > $CONFIG_FILE

SUCCESS_COUNT=0
FAILED_SITES=()

for site in "${SITES[@]}"; do
    # Skip comments and empty lines
    [[ "$site" =~ ^#.*$ ]] && continue
    [[ -z "$site" ]] && continue

    IFS=',' read -r name host node_port app_port app_path environment <<< "$site"

    # Set defaults
    node_port=${node_port:-9100}
    environment=${environment:-production}

    echo "Processing: $name ($host)"

    # Add node exporter config
    cat >> $CONFIG_FILE << EOF

  # $name monitoring
  - job_name: '${name}-node'
    static_configs:
      - targets: ['${host}:${node_port}']
        labels:
          site: '${name}'
          environment: '${environment}'
          type: 'infrastructure'
EOF

    # Add app metrics if provided
    if [ ! -z "$app_port" ]; then
        app_path=${app_path:-/metrics}
        cat >> $CONFIG_FILE << EOF

  - job_name: '${name}-app'
    metrics_path: '${app_path}'
    static_configs:
      - targets: ['${host}:${app_port}']
        labels:
          site: '${name}'
          environment: '${environment}'
          type: 'application'
EOF
    fi

    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
done

echo ""
echo "Generated configuration for $SUCCESS_COUNT sites"
echo ""

# Apply configuration to central monitoring
echo "Applying configuration to central monitoring..."

scp $CONFIG_FILE root@$MONITORING_IP:/tmp/migration-config.yml

ssh root@$MONITORING_IP << 'ENDSSH'
cd /opt/observability-stack

# Backup current config
BACKUP_FILE="prometheus/prometheus.yml.$(date +%Y%m%d-%H%M%S).bak"
cp prometheus/prometheus.yml "$BACKUP_FILE"
echo "Backed up current config to $BACKUP_FILE"

# Append new configuration
cat /tmp/migration-config.yml >> prometheus/prometheus.yml

# Validate configuration
docker-compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml

if [ $? -eq 0 ]; then
    echo "✅ Configuration valid, reloading Prometheus..."
    docker-compose exec -T prometheus kill -HUP 1
    echo "✅ Migration completed successfully!"

    # Show target status
    echo ""
    echo "Checking target status..."
    sleep 5
    curl -s http://localhost:9090/api/v1/targets | \
        jq -r '.data.activeTargets[] | "\(.labels.site // "unknown"): \(.health)"' | \
        sort -u
else
    echo "❌ Configuration invalid, restoring backup..."
    cp "$BACKUP_FILE" prometheus/prometheus.yml
    exit 1
fi

rm /tmp/migration-config.yml
ENDSSH

rm $CONFIG_FILE

echo ""
echo "=========================================="
echo "Migration Summary"
echo "=========================================="
echo "✅ Successfully migrated: $SUCCESS_COUNT sites"

if [ ${#FAILED_SITES[@]} -gt 0 ]; then
    echo "❌ Failed sites: ${FAILED_SITES[@]}"
fi

echo ""
echo "Next steps for each site:"
echo "1. Ensure node_exporter is running"
echo "2. Configure firewall rules:"
echo "   ufw allow from $MONITORING_IP to any port 9100"
echo "3. Test connectivity from central monitoring"
echo "4. Import Grafana dashboards"
echo ""
echo "View all targets: http://$MONITORING_IP:9090/targets"
echo "Access Grafana: http://$MONITORING_IP:3000"
echo ""

# Offer to test all sites
read -p "Test connectivity to all sites? (y/n): " TEST_ALL
if [ "$TEST_ALL" = "y" ]; then
    echo ""
    echo "Testing connectivity..."

    for site in "${SITES[@]}"; do
        [[ "$site" =~ ^#.*$ ]] && continue
        [[ -z "$site" ]] && continue

        IFS=',' read -r name host node_port app_port app_path environment <<< "$site"
        node_port=${node_port:-9100}

        echo -n "Testing $name ($host:$node_port): "
        ssh root@$MONITORING_IP "curl -s -o /dev/null -w '%{http_code}' http://$host:$node_port/metrics" || echo "Failed"
    done
fi