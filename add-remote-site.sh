#!/bin/bash

set -e

# Central monitoring droplet IP
MONITORING_IP="159.89.243.148"

echo "Add Remote Site to Central Monitoring"
echo "======================================"
echo ""

# Get site information
read -p "Site name (e.g., site1): " SITE_NAME
read -p "Site IP or hostname: " SITE_HOST
read -p "Node exporter port (default: 9100): " NODE_PORT
NODE_PORT=${NODE_PORT:-9100}

read -p "Does this site have custom app metrics? (y/n): " HAS_APP
if [ "$HAS_APP" = "y" ]; then
    read -p "App metrics port: " APP_PORT
    read -p "App metrics path (default: /metrics): " APP_PATH
    APP_PATH=${APP_PATH:-/metrics}
fi

read -p "Environment (production/staging/dev): " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-production}

read -p "Is this a DigitalOcean droplet with private networking? (y/n): " USE_PRIVATE
if [ "$USE_PRIVATE" = "y" ]; then
    read -p "Private IP address: " PRIVATE_IP
    SITE_HOST=$PRIVATE_IP
fi

echo ""
echo "Adding $SITE_NAME to monitoring..."

# Create the configuration
cat > /tmp/add-site-config.yml << EOF
  # $SITE_NAME monitoring
  - job_name: '${SITE_NAME}-node'
    static_configs:
      - targets: ['${SITE_HOST}:${NODE_PORT}']
        labels:
          site: '${SITE_NAME}'
          environment: '${ENVIRONMENT}'
          type: 'infrastructure'
EOF

if [ "$HAS_APP" = "y" ]; then
    cat >> /tmp/add-site-config.yml << EOF

  - job_name: '${SITE_NAME}-app'
    metrics_path: '${APP_PATH}'
    static_configs:
      - targets: ['${SITE_HOST}:${APP_PORT}']
        labels:
          site: '${SITE_NAME}'
          environment: '${ENVIRONMENT}'
          type: 'application'
EOF
fi

# Add to central Prometheus
ssh root@$MONITORING_IP << 'ENDSSH'
cd /opt/observability-stack

# Backup current config
cp prometheus/prometheus.yml prometheus/prometheus.yml.$(date +%Y%m%d-%H%M%S).bak

# Add new configuration
cat >> prometheus/prometheus.yml << 'ENDCONFIG'
$(cat /tmp/add-site-config.yml)
ENDCONFIG

# Validate configuration
docker-compose exec -T prometheus promtool check config /etc/prometheus/prometheus.yml

if [ $? -eq 0 ]; then
    echo "Configuration valid, reloading Prometheus..."
    docker-compose exec -T prometheus kill -HUP 1
    echo "✅ Site added successfully!"
else
    echo "❌ Configuration invalid, restoring backup..."
    cp prometheus/prometheus.yml.$(date +%Y%m%d-%H%M%S).bak prometheus/prometheus.yml
    exit 1
fi
ENDSSH

rm /tmp/add-site-config.yml

echo ""
echo "Site '$SITE_NAME' has been added to monitoring!"
echo ""
echo "Next steps:"
echo "1. Ensure node_exporter is running on $SITE_HOST:$NODE_PORT"
echo "2. Configure firewall to allow access from $MONITORING_IP"
echo "   On the site: ufw allow from $MONITORING_IP to any port $NODE_PORT"
echo "3. Check target status: http://$MONITORING_IP:9090/targets"
echo "4. View metrics in Grafana: http://$MONITORING_IP:3000"
echo ""

# Offer to test connectivity
read -p "Test connectivity to $SITE_HOST:$NODE_PORT? (y/n): " TEST
if [ "$TEST" = "y" ]; then
    ssh root@$MONITORING_IP "curl -s -o /dev/null -w '%{http_code}' http://$SITE_HOST:$NODE_PORT/metrics || echo 'Connection failed'"
fi