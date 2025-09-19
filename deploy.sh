#!/bin/bash

set -e

echo "Observability Stack Deployment Script"
echo "======================================"

if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp .env.example .env
    echo "Please edit .env file with your configuration before continuing."
    exit 1
fi

echo "Creating htpasswd file for Nginx basic auth..."
if ! command -v htpasswd &> /dev/null; then
    echo "Installing apache2-utils for htpasswd..."
    sudo apt-get update && sudo apt-get install -y apache2-utils
fi

if [ ! -f nginx/htpasswd ]; then
    read -p "Enter username for Prometheus/Alertmanager access: " username
    htpasswd -c nginx/htpasswd "$username"
else
    echo "htpasswd file already exists. Skipping..."
fi

echo "Pulling Docker images..."
docker-compose pull

echo "Starting services..."
docker-compose up -d

echo "Waiting for services to start..."
sleep 10

echo "Checking service health..."
docker-compose ps

echo ""
echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Access your services at:"
echo "  Grafana:      http://your-server-ip:3000"
echo "  Prometheus:   http://your-server-ip:9090"
echo "  Alertmanager: http://your-server-ip:9093"
echo ""
echo "Default Grafana credentials:"
echo "  Username: admin"
echo "  Password: (check your .env file)"
echo ""
echo "To view logs: docker-compose logs -f"
echo "To stop services: docker-compose down"
echo "To update services: docker-compose pull && docker-compose up -d"