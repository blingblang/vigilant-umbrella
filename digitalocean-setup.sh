#!/bin/bash

set -e

echo "DigitalOcean Observability Stack Deployment"
echo "==========================================="
echo ""

# Check for required tools
if ! command -v ssh &> /dev/null; then
    echo "Error: ssh is required but not installed."
    exit 1
fi

# Configuration
read -p "Enter your DigitalOcean Droplet IP address: " DROPLET_IP
if [ -z "$DROPLET_IP" ]; then
    echo "Error: IP address is required"
    exit 1
fi

read -p "Enter SSH user (default: root): " SSH_USER
SSH_USER=${SSH_USER:-root}

read -p "Enter Grafana admin password (default: auto-generated): " GRAFANA_PASSWORD
if [ -z "$GRAFANA_PASSWORD" ]; then
    GRAFANA_PASSWORD=$(openssl rand -base64 12)
    echo "Generated Grafana password: $GRAFANA_PASSWORD"
fi

read -p "Enter your email for alerts: " ALERT_EMAIL
read -p "Enter Slack webhook URL (optional): " SLACK_WEBHOOK

echo ""
echo "Configuration:"
echo "  Droplet IP: $DROPLET_IP"
echo "  SSH User: $SSH_USER"
echo "  Alert Email: $ALERT_EMAIL"
echo ""
read -p "Deploy to this droplet? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 1
fi

echo ""
echo "Creating deployment package..."

# Create a temporary directory for deployment files
DEPLOY_DIR=$(mktemp -d)
cp -r . "$DEPLOY_DIR/observability-stack"
cd "$DEPLOY_DIR/observability-stack"

# Update .env file with user configurations
cat > .env << EOF
GRAFANA_USER=admin
GRAFANA_PASSWORD=$GRAFANA_PASSWORD
ALERT_EMAIL=$ALERT_EMAIL
SLACK_WEBHOOK=$SLACK_WEBHOOK
EOF

# Create deployment script that will run on the droplet
cat > setup-on-droplet.sh << 'SCRIPT_EOF'
#!/bin/bash
set -e

echo "Starting observability stack setup on droplet..."

# Update system
echo "Updating system packages..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Install required packages
echo "Installing required packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y apache2-utils ufw

# Setup firewall
echo "Configuring firewall..."
ufw --force disable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp
ufw allow 9090/tcp
ufw allow 9093/tcp
ufw allow 9100/tcp
ufw allow 9115/tcp
ufw --force enable

# Move to installation directory
cd /opt/observability-stack

# Create htpasswd file for basic auth
echo "Setting up authentication..."
htpasswd -b -c nginx/htpasswd admin $(grep GRAFANA_PASSWORD .env | cut -d '=' -f2)

# Update Alertmanager config with actual email
if [ ! -z "$(grep ALERT_EMAIL .env | cut -d '=' -f2)" ]; then
    EMAIL=$(grep ALERT_EMAIL .env | cut -d '=' -f2)
    sed -i "s/team@yourdomain.com/$EMAIL/g" alertmanager/alertmanager.yml
    sed -i "s/oncall@yourdomain.com/$EMAIL/g" alertmanager/alertmanager.yml
    sed -i "s/monitoring@yourdomain.com/$EMAIL/g" alertmanager/alertmanager.yml
fi

# Update Slack webhook if provided
if [ ! -z "$(grep SLACK_WEBHOOK .env | cut -d '=' -f2)" ]; then
    WEBHOOK=$(grep SLACK_WEBHOOK .env | cut -d '=' -f2)
    sed -i "s|YOUR_SLACK_WEBHOOK_URL|$WEBHOOK|g" alertmanager/alertmanager.yml
fi

# Start the stack
echo "Starting Docker containers..."
docker-compose pull
docker-compose up -d

# Wait for services to start
echo "Waiting for services to initialize..."
sleep 15

# Check service health
echo "Checking service status..."
docker-compose ps

echo ""
echo "======================================"
echo "Setup completed successfully!"
echo "======================================"
SCRIPT_EOF

chmod +x setup-on-droplet.sh

# Create tarball of all files
echo "Creating deployment package..."
cd "$DEPLOY_DIR"
tar -czf observability-stack.tar.gz observability-stack/

# Copy files to droplet
echo ""
echo "Copying files to droplet..."
scp observability-stack.tar.gz $SSH_USER@$DROPLET_IP:/tmp/

# Execute setup on droplet
echo ""
echo "Executing setup on droplet..."
ssh $SSH_USER@$DROPLET_IP << 'REMOTE_EOF'
set -e
cd /opt
rm -rf observability-stack
tar -xzf /tmp/observability-stack.tar.gz
cd observability-stack
bash setup-on-droplet.sh
rm /tmp/observability-stack.tar.gz
REMOTE_EOF

# Cleanup local temp files
rm -rf "$DEPLOY_DIR"

# Display success message
echo ""
echo "==========================================="
echo "Deployment Complete!"
echo "==========================================="
echo ""
echo "Your observability stack is now running at:"
echo ""
echo "  Grafana:      http://$DROPLET_IP:3000"
echo "              Username: admin"
echo "              Password: $GRAFANA_PASSWORD"
echo ""
echo "  Prometheus:   http://$DROPLET_IP:9090"
echo "              Username: admin"
echo "              Password: $GRAFANA_PASSWORD"
echo ""
echo "  Alertmanager: http://$DROPLET_IP:9093"
echo "              Username: admin"
echo "              Password: $GRAFANA_PASSWORD"
echo ""
echo "To add websites to monitor:"
echo "  1. SSH into your droplet: ssh $SSH_USER@$DROPLET_IP"
echo "  2. Edit: /opt/observability-stack/prometheus/prometheus.yml"
echo "  3. Reload: docker-compose -f /opt/observability-stack/docker-compose.yml restart prometheus"
echo ""
echo "To view logs:"
echo "  ssh $SSH_USER@$DROPLET_IP 'cd /opt/observability-stack && docker-compose logs -f'"
echo ""