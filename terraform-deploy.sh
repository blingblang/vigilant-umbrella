#!/bin/bash

set -e

echo "Terraform Observability Stack Deployment"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform is not installed!${NC}"
    echo ""
    echo "Install Terraform:"
    echo "  macOS:  brew install terraform"
    echo "  Linux:  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg"
    echo "  Windows: choco install terraform"
    echo ""
    echo "Or visit: https://www.terraform.io/downloads"
    exit 1
fi

# Check Terraform version
TERRAFORM_VERSION=$(terraform version -json | grep -o '"terraform_version":"[^"]*' | grep -o '[^"]*$')
echo "Found Terraform version: $TERRAFORM_VERSION"
echo ""

# Change to terraform directory
cd terraform

# Check if terraform has been initialized
if [ ! -d ".terraform" ]; then
    echo -e "${YELLOW}Initializing Terraform...${NC}"
    terraform init
    echo ""
fi

# Check for existing tfvars file
if [ ! -f "terraform.tfvars" ]; then
    if [ -f "terraform.tfvars.example" ]; then
        echo -e "${YELLOW}No terraform.tfvars found. Creating from example...${NC}"
        cp terraform.tfvars.example terraform.tfvars

        echo ""
        echo -e "${RED}IMPORTANT: Edit terraform/terraform.tfvars with your configuration:${NC}"
        echo "  1. Add your DigitalOcean API token"
        echo "  2. Set your alert email address"
        echo "  3. Add websites to monitor"
        echo "  4. Configure SMTP settings for email alerts"
        echo ""
        read -p "Press Enter after editing terraform.tfvars to continue..."
    fi
fi

# Interactive configuration if no token is set
if grep -q "your-digitalocean-api-token" terraform.tfvars 2>/dev/null; then
    echo -e "${YELLOW}Setting up configuration...${NC}"
    echo ""

    read -p "Enter your DigitalOcean API token: " DO_TOKEN
    sed -i.bak "s/your-digitalocean-api-token/$DO_TOKEN/" terraform.tfvars

    read -p "Enter email for alerts: " ALERT_EMAIL
    sed -i.bak "s/your-email@example.com/$ALERT_EMAIL/" terraform.tfvars

    read -p "Enter Slack webhook URL (optional, press Enter to skip): " SLACK_WEBHOOK
    if [ ! -z "$SLACK_WEBHOOK" ]; then
        sed -i.bak "s|# slack_webhook_url = .*|slack_webhook_url = \"$SLACK_WEBHOOK\"|" terraform.tfvars
    fi

    echo ""
    echo -e "${GREEN}Configuration updated!${NC}"
fi

# Validate configuration
echo ""
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
if terraform validate; then
    echo -e "${GREEN}Configuration is valid!${NC}"
else
    echo -e "${RED}Configuration validation failed. Please check your terraform.tfvars file.${NC}"
    exit 1
fi

# Show the plan
echo ""
echo -e "${YELLOW}Planning infrastructure changes...${NC}"
terraform plan -out=tfplan

echo ""
echo -e "${YELLOW}The following resources will be created:${NC}"
terraform show -no-color tfplan | grep "will be created" | head -20

echo ""
read -p "Do you want to apply these changes? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    rm tfplan
    exit 0
fi

# Apply the configuration
echo ""
echo -e "${YELLOW}Creating infrastructure...${NC}"
terraform apply tfplan

# Clean up plan file
rm tfplan

# Get outputs
echo ""
echo -e "${GREEN}Deployment Complete!${NC}"
echo ""
echo "==========================================="
echo "Observability Stack Successfully Deployed!"
echo "==========================================="
echo ""

# Display access information
DROPLET_IP=$(terraform output -raw droplet_ip)
GRAFANA_URL=$(terraform output -raw grafana_url)
GRAFANA_PASSWORD=$(terraform output -raw grafana_password)

echo "Access your services:"
echo -e "  Grafana:      ${GREEN}$GRAFANA_URL${NC}"
echo -e "  Prometheus:   ${GREEN}http://$DROPLET_IP:9090${NC}"
echo -e "  Alertmanager: ${GREEN}http://$DROPLET_IP:9093${NC}"
echo ""
echo "Credentials:"
echo "  Username: admin"
echo -e "  Password: ${YELLOW}$GRAFANA_PASSWORD${NC}"
echo ""
echo "SSH Access:"
echo -e "  ${GREEN}ssh root@$DROPLET_IP${NC}"
echo ""
echo "Remote Management:"
echo -e "  ${GREEN}./remote-manage.sh $DROPLET_IP${NC}"
echo ""

# Save credentials to file
cat > ../credentials.txt << EOF
Observability Stack Credentials
================================
Deployed: $(date)

Droplet IP: $DROPLET_IP
Grafana URL: $GRAFANA_URL

Username: admin
Password: $GRAFANA_PASSWORD

SSH: ssh root@$DROPLET_IP
EOF

echo -e "${YELLOW}Credentials saved to credentials.txt${NC}"
echo ""

# Offer to test the deployment
read -p "Would you like to test the deployment? (yes/no): " TEST_DEPLOY
if [ "$TEST_DEPLOY" == "yes" ]; then
    echo ""
    echo "Testing deployment..."

    # Wait for services to be ready
    echo "Waiting for services to start (30 seconds)..."
    sleep 30

    # Test Grafana
    if curl -s -o /dev/null -w "%{http_code}" "$GRAFANA_URL" | grep -q "200\|302"; then
        echo -e "  Grafana: ${GREEN}✓ Running${NC}"
    else
        echo -e "  Grafana: ${RED}✗ Not responding${NC}"
    fi

    # Test Prometheus
    if curl -s -o /dev/null -w "%{http_code}" "http://$DROPLET_IP:9090" | grep -q "200\|401"; then
        echo -e "  Prometheus: ${GREEN}✓ Running${NC}"
    else
        echo -e "  Prometheus: ${RED}✗ Not responding${NC}"
    fi

    # Test Alertmanager
    if curl -s -o /dev/null -w "%{http_code}" "http://$DROPLET_IP:9093" | grep -q "200\|401"; then
        echo -e "  Alertmanager: ${GREEN}✓ Running${NC}"
    else
        echo -e "  Alertmanager: ${RED}✗ Not responding${NC}"
    fi
fi

echo ""
echo "Next steps:"
echo "  1. Access Grafana at $GRAFANA_URL"
echo "  2. Configure additional websites to monitor"
echo "  3. Set up notification channels in Alertmanager"
echo "  4. Import additional Grafana dashboards"
echo ""
echo -e "${GREEN}Deployment complete!${NC}"