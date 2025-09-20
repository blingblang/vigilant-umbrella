#!/bin/bash

echo "Checking Observability Stack Status on 159.89.243.148"
echo "======================================================"
echo ""

# Try to SSH and check services
echo "Attempting to connect to droplet..."

ssh -o ConnectTimeout=10 root@159.89.243.148 << 'ENDSSH' 2>&1
echo "Connected successfully!"
echo ""

# Check if Docker is running
echo "Docker status:"
systemctl is-active docker

echo ""
echo "Docker Compose services:"
cd /opt/observability-stack 2>/dev/null || cd /opt 2>/dev/null
if [ -f docker-compose.yml ]; then
    docker-compose ps
else
    docker ps
fi

echo ""
echo "Port listening status:"
netstat -tuln | grep -E ":(3000|9090|9093|9100|9115) "

echo ""
echo "Firewall status:"
ufw status numbered | grep -E "(9090|3000|9093)"

echo ""
echo "Testing local connectivity:"
curl -s -o /dev/null -w "Prometheus (9090): %{http_code}\n" http://localhost:9090 || echo "Prometheus: Failed"
curl -s -o /dev/null -w "Grafana (3000): %{http_code}\n" http://localhost:3000 || echo "Grafana: Failed"
curl -s -o /dev/null -w "Alertmanager (9093): %{http_code}\n" http://localhost:9093 || echo "Alertmanager: Failed"

echo ""
echo "Recent Docker logs (Prometheus):"
docker logs prometheus --tail 20 2>&1 | head -20

ENDSSH

if [ $? -ne 0 ]; then
    echo ""
    echo "Could not connect via SSH. Checking external connectivity..."
    echo ""

    # Test from local machine
    echo "Testing from your local machine:"
    echo -n "Grafana (3000): "
    curl -s -o /dev/null -w "%{http_code}\n" -m 5 http://159.89.243.148:3000 || echo "Connection failed"

    echo -n "Prometheus (9090): "
    curl -s -o /dev/null -w "%{http_code}\n" -m 5 http://159.89.243.148:9090 || echo "Connection failed"

    echo -n "Alertmanager (9093): "
    curl -s -o /dev/null -w "%{http_code}\n" -m 5 http://159.89.243.148:9093 || echo "Connection failed"

    echo ""
    echo "Checking if droplet is reachable:"
    ping -n 3 159.89.243.148 2>nul || ping -c 3 159.89.243.148
fi