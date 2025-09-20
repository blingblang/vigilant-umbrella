#!/bin/bash

echo "Fixing Observability Stack on Droplet"
echo "======================================"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    systemctl start docker
    systemctl enable docker
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose not found. Installing..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Check if observability stack exists
if [ ! -d /opt/observability-stack ]; then
    echo "Observability stack not found. Creating from scratch..."

    # Clone the repository
    cd /opt
    git clone https://github.com/blingblang/vigilant-umbrella.git observability-stack
    cd observability-stack

    # Create .env file
    cat > .env << 'EOF'
GRAFANA_USER=admin
GRAFANA_PASSWORD=admin-password-change-me
EOF

    # Create htpasswd
    apt-get update && apt-get install -y apache2-utils
    htpasswd -b -c nginx/htpasswd admin admin-password-change-me
else
    echo "Found observability stack at /opt/observability-stack"
    cd /opt/observability-stack
fi

# Check current Docker containers
echo ""
echo "Current Docker status:"
docker ps -a

# Stop any existing containers
echo ""
echo "Stopping any existing containers..."
docker-compose down 2>/dev/null || true

# Pull latest images
echo ""
echo "Pulling Docker images..."
docker-compose pull

# Start services
echo ""
echo "Starting services..."
docker-compose up -d

# Wait for services to start
echo ""
echo "Waiting for services to initialize..."
sleep 10

# Check service status
echo ""
echo "Service status:"
docker-compose ps

# Test connectivity
echo ""
echo "Testing service connectivity:"
curl -s -o /dev/null -w "Grafana (3000): %{http_code}\n" http://localhost:3000
curl -s -o /dev/null -w "Prometheus (9090): %{http_code}\n" http://localhost:9090
curl -s -o /dev/null -w "Alertmanager (9093): %{http_code}\n" http://localhost:9093

# Check firewall
echo ""
echo "Checking firewall rules:"
ufw status | grep -E "(3000|9090|9093)" || echo "Ports might not be open in firewall"

# If ports aren't open, add them
if ! ufw status | grep -q "3000"; then
    echo "Opening required ports..."
    ufw allow 3000/tcp
    ufw allow 9090/tcp
    ufw allow 9093/tcp
    ufw allow 9100/tcp
    ufw reload
fi

echo ""
echo "======================================"
echo "Fix attempt complete!"
echo "======================================"
echo ""
echo "Services should now be accessible at:"
echo "  Grafana: http://$(curl -s ifconfig.me):3000"
echo "  Prometheus: http://$(curl -s ifconfig.me):9090"
echo "  Alertmanager: http://$(curl -s ifconfig.me):9093"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: admin-password-change-me"
echo ""
echo "If services still aren't working, check logs:"
echo "  docker-compose logs prometheus"
echo "  docker-compose logs grafana"