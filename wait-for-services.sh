#!/bin/bash

DROPLET_IP="159.89.243.148"
MAX_ATTEMPTS=20
ATTEMPT=0

echo "Waiting for Observability Stack to be ready at $DROPLET_IP"
echo "This can take 5-10 minutes after deployment..."
echo ""

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo -n "Attempt $ATTEMPT/$MAX_ATTEMPTS: "

    # Try Grafana first (most likely to be up)
    if curl -s -o /dev/null -w "%{http_code}" -m 5 http://$DROPLET_IP:3000 | grep -q "200\|302"; then
        echo "✅ Grafana is responding!"
        echo ""
        echo "Testing all services:"
        echo -n "  Grafana (3000): "
        curl -s -o /dev/null -w "%{http_code}\n" -m 5 http://$DROPLET_IP:3000

        echo -n "  Prometheus (9090): "
        curl -s -o /dev/null -w "%{http_code}\n" -m 5 http://$DROPLET_IP:9090

        echo -n "  Alertmanager (9093): "
        curl -s -o /dev/null -w "%{http_code}\n" -m 5 http://$DROPLET_IP:9093

        echo ""
        echo "Services are ready! Access them at:"
        echo "  Grafana: http://$DROPLET_IP:3000"
        echo "  Prometheus: http://$DROPLET_IP:9090"
        echo "  Alertmanager: http://$DROPLET_IP:9093"
        exit 0
    else
        echo "Not ready yet. Waiting 30 seconds..."
        sleep 30
    fi
done

echo ""
echo "❌ Services did not come up after $MAX_ATTEMPTS attempts"
echo ""
echo "Please check:"
echo "1. Terraform Cloud: https://app.terraform.io"
echo "2. DigitalOcean Dashboard: https://cloud.digitalocean.com/droplets"
echo "3. Try SSH: ssh root@$DROPLET_IP"