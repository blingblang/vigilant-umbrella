#!/bin/bash

# Script to configure exporters on your existing sites to work with central monitoring
# Run this ON EACH SITE that needs to be monitored

set -e

CENTRAL_MONITOR_IP="159.89.243.148"

echo "Configure Site for Central Monitoring"
echo "====================================="
echo ""
echo "This script will configure this site to be monitored by $CENTRAL_MONITOR_IP"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Detect if node_exporter is already running
NODE_EXPORTER_RUNNING=false
if systemctl is-active --quiet node_exporter; then
    NODE_EXPORTER_RUNNING=true
    echo "✅ Node exporter is already running as a service"
elif docker ps | grep -q node-exporter; then
    NODE_EXPORTER_RUNNING=true
    echo "✅ Node exporter is running in Docker"
else
    echo "❌ Node exporter not detected"
fi

# Install or verify node_exporter
if [ "$NODE_EXPORTER_RUNNING" = false ]; then
    read -p "Install node_exporter? (y/n): " INSTALL_NODE

    if [ "$INSTALL_NODE" = "y" ]; then
        echo "Choose installation method:"
        echo "1) Docker"
        echo "2) Native systemd service"
        read -p "Enter choice (1-2): " INSTALL_METHOD

        if [ "$INSTALL_METHOD" = "1" ]; then
            # Docker installation
            echo "Installing node_exporter via Docker..."

            docker run -d \
                --name node-exporter \
                --restart unless-stopped \
                -p 9100:9100 \
                -v /proc:/host/proc:ro \
                -v /sys:/host/sys:ro \
                -v /:/rootfs:ro \
                prom/node-exporter:latest \
                --path.procfs=/host/proc \
                --path.sysfs=/host/sys \
                --path.rootfs=/rootfs \
                --collector.filesystem.mount-points-exclude='^/(sys|proc|dev|host|etc)($$|/)'

            echo "✅ Node exporter installed via Docker"

        elif [ "$INSTALL_METHOD" = "2" ]; then
            # Native installation
            echo "Installing node_exporter as systemd service..."

            # Download and install
            cd /tmp
            wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
            tar xzf node_exporter-1.6.1.linux-amd64.tar.gz
            cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/

            # Create systemd service
            cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=nobody
Group=nogroup
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reload
            systemctl enable node_exporter
            systemctl start node_exporter

            echo "✅ Node exporter installed as systemd service"
        fi
    fi
fi

# Configure firewall
echo ""
echo "Configuring firewall rules..."

# Check which firewall is in use
if command -v ufw &> /dev/null; then
    echo "Using UFW firewall"
    ufw allow from $CENTRAL_MONITOR_IP to any port 9100 comment 'Central monitoring node_exporter'

    # If you have app metrics
    read -p "Do you have application metrics to expose? (y/n): " HAS_APP
    if [ "$HAS_APP" = "y" ]; then
        read -p "Application metrics port: " APP_PORT
        ufw allow from $CENTRAL_MONITOR_IP to any port $APP_PORT comment 'Central monitoring app metrics'
    fi

    ufw reload
    echo "✅ Firewall rules added"

elif command -v firewall-cmd &> /dev/null; then
    echo "Using firewalld"
    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='$CENTRAL_MONITOR_IP' port port='9100' protocol='tcp' accept"
    firewall-cmd --reload
    echo "✅ Firewall rules added"

elif command -v iptables &> /dev/null; then
    echo "Using iptables"
    iptables -A INPUT -p tcp -s $CENTRAL_MONITOR_IP --dport 9100 -j ACCEPT

    # Save iptables rules
    if [ -f /etc/debian_version ]; then
        iptables-save > /etc/iptables/rules.v4
    elif [ -f /etc/redhat-release ]; then
        service iptables save
    fi
    echo "✅ Firewall rules added"
else
    echo "⚠️  No firewall detected. Please manually configure."
fi

# Test connectivity
echo ""
echo "Testing node_exporter..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:9100/metrics | grep -q "200"; then
    echo "✅ Node exporter is responding locally"
else
    echo "❌ Node exporter is not responding. Please check the installation."
    exit 1
fi

# Get site information for central config
echo ""
echo "Site Configuration"
echo "=================="
HOSTNAME=$(hostname)
echo "Hostname: $HOSTNAME"

# Try to get public IP
PUBLIC_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "unknown")
echo "Public IP: $PUBLIC_IP"

# Check for private IP (DigitalOcean)
PRIVATE_IP=$(ip addr | grep -E '10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.' | awk '{print $2}' | cut -d'/' -f1 | head -1)
if [ ! -z "$PRIVATE_IP" ]; then
    echo "Private IP: $PRIVATE_IP"
fi

echo ""
echo "=========================================="
echo "✅ Site Configuration Complete!"
echo "=========================================="
echo ""
echo "Add this site to central monitoring by running on your local machine:"
echo ""
echo "./add-remote-site.sh"
echo ""
echo "Use these values when prompted:"
echo "  Site name: $HOSTNAME"
if [ ! -z "$PRIVATE_IP" ] && [[ "$PRIVATE_IP" =~ ^10\. ]]; then
    echo "  Site IP: $PRIVATE_IP (private network recommended)"
else
    echo "  Site IP: $PUBLIC_IP"
fi
echo "  Node exporter port: 9100"
echo ""
echo "Or manually add to prometheus.yml on $CENTRAL_MONITOR_IP:"
echo ""
echo "  - job_name: '${HOSTNAME}-node'"
echo "    static_configs:"
echo "      - targets: ['${PUBLIC_IP}:9100']"
echo "        labels:"
echo "          site: '${HOSTNAME}'"
echo "          environment: 'production'"
echo ""

# Test from central monitor
read -p "Test connection from central monitor? (y/n): " TEST_CENTRAL
if [ "$TEST_CENTRAL" = "y" ]; then
    echo ""
    echo "To test from central monitor, run:"
    echo "ssh root@$CENTRAL_MONITOR_IP 'curl -v http://$PUBLIC_IP:9100/metrics'"
fi