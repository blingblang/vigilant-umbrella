#!/bin/bash

set -e

echo "DigitalOcean Droplet Creator with Observability Stack"
echo "======================================================"
echo ""
echo "This script will create a new DigitalOcean droplet and automatically"
echo "deploy the complete observability stack (Grafana, Prometheus, Alertmanager)."
echo ""

# Check for doctl CLI
if ! command -v doctl &> /dev/null; then
    echo "doctl CLI not found. Please install it first:"
    echo "  brew install doctl (macOS)"
    echo "  snap install doctl (Linux)"
    echo "  Or visit: https://docs.digitalocean.com/reference/doctl/how-to/install/"
    exit 1
fi

# Get configuration
read -p "Enter droplet name (default: observability): " DROPLET_NAME
DROPLET_NAME=${DROPLET_NAME:-observability}

echo ""
echo "Select a region:"
echo "  1) nyc1 - New York 1"
echo "  2) nyc3 - New York 3"
echo "  3) sfo3 - San Francisco 3"
echo "  4) ams3 - Amsterdam 3"
echo "  5) lon1 - London 1"
echo "  6) fra1 - Frankfurt 1"
echo "  7) tor1 - Toronto 1"
echo "  8) sgp1 - Singapore 1"
read -p "Enter choice (1-8, default: 1): " REGION_CHOICE
case $REGION_CHOICE in
    2) REGION="nyc3" ;;
    3) REGION="sfo3" ;;
    4) REGION="ams3" ;;
    5) REGION="lon1" ;;
    6) REGION="fra1" ;;
    7) REGION="tor1" ;;
    8) REGION="sgp1" ;;
    *) REGION="nyc1" ;;
esac

echo ""
echo "Select droplet size:"
echo "  1) s-1vcpu-1gb   - $6/month  (Basic - Testing only)"
echo "  2) s-2vcpu-2gb   - $18/month (Light usage)"
echo "  3) s-2vcpu-4gb   - $24/month (Recommended)"
echo "  4) s-4vcpu-8gb   - $48/month (Heavy usage)"
read -p "Enter choice (1-4, default: 3): " SIZE_CHOICE
case $SIZE_CHOICE in
    1) SIZE="s-1vcpu-1gb" ;;
    2) SIZE="s-2vcpu-2gb" ;;
    4) SIZE="s-4vcpu-8gb" ;;
    *) SIZE="s-2vcpu-4gb" ;;
esac

read -p "Enter Grafana admin password: " GRAFANA_PASSWORD
while [ -z "$GRAFANA_PASSWORD" ]; do
    echo "Password cannot be empty!"
    read -p "Enter Grafana admin password: " GRAFANA_PASSWORD
done

read -p "Enter email for alerts: " ALERT_EMAIL
read -p "Enter Slack webhook URL (optional): " SLACK_WEBHOOK

# Get SSH keys
echo ""
echo "Available SSH keys:"
doctl compute ssh-key list
read -p "Enter SSH key ID or fingerprint (or press enter to use first available): " SSH_KEY
if [ -z "$SSH_KEY" ]; then
    SSH_KEY=$(doctl compute ssh-key list --format ID --no-header | head -n1)
fi

# Create cloud-init script
cat > /tmp/cloud-init.yaml << EOF
#cloud-config
package_upgrade: true
packages:
  - docker.io
  - docker-compose
  - apache2-utils
  - ufw
  - git

write_files:
  - path: /opt/setup-observability.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -e

      # Clone the repository
      cd /opt
      git clone https://github.com/yourusername/observability-stack.git || true

      # If git clone fails, create the structure manually
      if [ ! -d /opt/observability-stack ]; then
        mkdir -p /opt/observability-stack
        cd /opt/observability-stack

        # Create all necessary directories
        mkdir -p prometheus alertmanager grafana/provisioning/datasources
        mkdir -p grafana/provisioning/dashboards grafana/dashboards
        mkdir -p blackbox nginx
      fi

      cd /opt/observability-stack

      # Write all configuration files
      $(cat docker-compose.yml | sed 's/$/\\/' | sed 's/"/\\"/g')

      echo "Stack files created. Starting services..."

      # Create .env file
      cat > .env << 'ENV_EOF'
      GRAFANA_USER=admin
      GRAFANA_PASSWORD=$GRAFANA_PASSWORD
      ENV_EOF

      # Create htpasswd
      htpasswd -b -c nginx/htpasswd admin "$GRAFANA_PASSWORD"

      # Start services
      docker-compose up -d

      echo "Observability stack deployed successfully!"

runcmd:
  - systemctl enable docker
  - systemctl start docker
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw allow 3000/tcp
  - ufw allow 9090/tcp
  - ufw allow 9093/tcp
  - ufw --force enable
  - /opt/setup-observability.sh

final_message: "Observability stack is ready!"
EOF

echo ""
echo "Creating Droplet..."
echo "  Name: $DROPLET_NAME"
echo "  Region: $REGION"
echo "  Size: $SIZE"
echo ""

# Create the droplet
doctl compute droplet create "$DROPLET_NAME" \
    --image ubuntu-22-04-x64 \
    --size "$SIZE" \
    --region "$REGION" \
    --ssh-keys "$SSH_KEY" \
    --user-data-file /tmp/cloud-init.yaml \
    --wait

# Get droplet IP
echo "Waiting for droplet to be ready..."
sleep 10
IP=$(doctl compute droplet get "$DROPLET_NAME" --format PublicIPv4 --no-header)

echo "Droplet created with IP: $IP"

# Wait for cloud-init to complete
echo "Waiting for initial setup to complete (this may take 3-5 minutes)..."
sleep 180

# Deploy the observability stack
echo "Deploying observability stack..."
./digitalocean-setup.sh <<INPUT
$IP
root
$GRAFANA_PASSWORD
$ALERT_EMAIL
$SLACK_WEBHOOK
yes
INPUT

echo ""
echo "==========================================="
echo "Droplet Created and Stack Deployed!"
echo "==========================================="
echo ""
echo "Droplet Details:"
echo "  Name: $DROPLET_NAME"
echo "  IP: $IP"
echo "  Size: $SIZE"
echo "  Region: $REGION"
echo ""
echo "Access your services:"
echo "  Grafana: http://$IP:3000"
echo "  Prometheus: http://$IP:9090"
echo "  Alertmanager: http://$IP:9093"
echo ""
echo "Credentials:"
echo "  Username: admin"
echo "  Password: $GRAFANA_PASSWORD"
echo ""
echo "SSH Access:"
echo "  ssh root@$IP"
echo ""
echo "To manage the droplet:"
echo "  doctl compute droplet delete $DROPLET_NAME (to destroy)"
echo "  doctl compute droplet-action reboot $DROPLET_NAME (to reboot)"
echo ""