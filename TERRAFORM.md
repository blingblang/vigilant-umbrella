# Terraform Deployment Guide

This guide covers deploying the observability stack using Terraform for infrastructure-as-code management.

## Why Use Terraform?

Terraform provides several advantages over manual deployment:

- **Infrastructure as Code**: Version control your infrastructure
- **Reproducibility**: Deploy identical stacks across environments
- **State Management**: Track and manage infrastructure changes
- **Resource Dependencies**: Automatic handling of resource relationships
- **Disaster Recovery**: Quickly rebuild infrastructure from code
- **Team Collaboration**: Share and review infrastructure changes

## Prerequisites

1. **Install Terraform** (v1.0+):
   ```bash
   # macOS
   brew install terraform

   # Linux
   wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
   sudo apt-get update && sudo apt-get install terraform

   # Windows
   choco install terraform
   ```

2. **DigitalOcean API Token**:
   - Get from: https://cloud.digitalocean.com/account/api/tokens
   - Required permissions: Read and Write

3. **SSH Key** (optional):
   - Generate: `ssh-keygen -t rsa -b 4096`
   - Or use existing DigitalOcean SSH keys

## Quick Start

### 1. One-Command Deployment

```bash
chmod +x terraform-deploy.sh
./terraform-deploy.sh
```

This interactive script will:
- Check for Terraform installation
- Initialize Terraform
- Guide you through configuration
- Deploy the entire stack
- Display access credentials

### 2. Manual Deployment

```bash
cd terraform

# Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure
terraform apply

# Get credentials
terraform output grafana_password
```

## Configuration Options

### Basic Configuration (terraform.tfvars)

```hcl
# Required
do_token    = "your-digitalocean-api-token"
alert_email = "alerts@yourcompany.com"

# Droplet Settings
droplet_name = "monitoring-prod"
region       = "nyc3"
droplet_size = "s-2vcpu-4gb"  # $24/month

# Websites to Monitor
websites_to_monitor = [
  { url = "https://example.com", label = "Main Site" },
  { url = "https://api.example.com", label = "API" },
  { url = "https://app.example.com", label = "Application" }
]
```

### Advanced Configuration

```hcl
# Security - Restrict access
ssh_allowed_ips = ["office.ip.address/32"]
monitoring_allowed_ips = ["office.ip.address/32", "vpn.ip.range/24"]

# High Availability
use_reserved_ip = true  # Keep same IP if recreating

# DNS Management
manage_dns  = true
domain_name = "example.com"
subdomain   = "monitoring"  # Creates monitoring.example.com

# SSL with Let's Encrypt
enable_ssl        = true
letsencrypt_email = "admin@example.com"

# Automated Backups
enable_backup_bucket  = true
backup_retention_days = 30

# Email Configuration
smtp_host     = "smtp.sendgrid.net:587"
smtp_username = "apikey"
smtp_password = "your-sendgrid-api-key"

# Slack Integration
slack_webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK"
```

## Terraform Commands

### Basic Operations

```bash
# Initialize (first time)
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# Show current state
terraform show

# List resources
terraform state list
```

### Working with Outputs

```bash
# Show all outputs
terraform output

# Get specific output
terraform output droplet_ip
terraform output -raw grafana_password

# Save outputs to file
terraform output -json > outputs.json
```

### State Management

```bash
# Refresh state
terraform refresh

# Import existing resources
terraform import digitalocean_droplet.observability <droplet-id>

# Remove resource from state
terraform state rm digitalocean_droplet.observability
```

## Deployment Scenarios

### Development Environment

```hcl
# terraform/environments/dev.tfvars
environment  = "dev"
droplet_size = "s-1vcpu-1gb"  # $6/month
websites_to_monitor = [
  { url = "https://dev.example.com", label = "Dev Site" }
]
```

Deploy: `terraform apply -var-file=environments/dev.tfvars`

### Production Environment

```hcl
# terraform/environments/prod.tfvars
environment     = "production"
droplet_size    = "s-4vcpu-8gb"  # $48/month
use_reserved_ip = true
enable_ssl      = true
enable_backup_bucket = true
```

Deploy: `terraform apply -var-file=environments/prod.tfvars`

### Multi-Region Deployment

Create multiple terraform workspaces:

```bash
# Create workspaces
terraform workspace new us-east
terraform workspace new eu-west

# Deploy to US East
terraform workspace select us-east
terraform apply -var="region=nyc3"

# Deploy to EU West
terraform workspace select eu-west
terraform apply -var="region=ams3"
```

## Managing Infrastructure

### Adding Websites

1. Edit `terraform.tfvars`:
   ```hcl
   websites_to_monitor = [
     { url = "https://new-site.com", label = "New Site" },
     # ... existing sites
   ]
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

### Scaling Resources

```bash
# Upgrade droplet size
terraform apply -var="droplet_size=s-4vcpu-8gb"

# Add more storage (requires custom config)
terraform apply -var="enable_block_storage=true"
```

### Updating Services

The stack auto-updates on deployment. To manually update:

```bash
# Force recreation of droplet
terraform apply -replace="digitalocean_droplet.observability"
```

## Backup and Recovery

### Automated Backups

When `enable_backup_bucket = true`:
- Daily backups to DigitalOcean Spaces
- Automatic retention management
- Accessible via S3-compatible tools

### Manual Backup

```bash
# Create snapshot
doctl compute droplet-action snapshot <droplet-id> --snapshot-name "backup-$(date +%Y%m%d)"

# Restore from snapshot
terraform apply -var="droplet_image=<snapshot-id>"
```

### Disaster Recovery

1. **Save Terraform state**:
   ```bash
   # Backup state file
   cp terraform.tfstate terraform.tfstate.backup

   # Use remote state (recommended)
   terraform {
     backend "s3" {
       endpoint = "nyc3.digitaloceanspaces.com"
       bucket   = "terraform-state"
       key      = "observability/terraform.tfstate"
       region   = "us-east-1"
     }
   }
   ```

2. **Restore infrastructure**:
   ```bash
   # From backup
   terraform apply

   # From specific state
   terraform apply -state=terraform.tfstate.backup
   ```

## Security Best Practices

### 1. Secrets Management

Never commit secrets to Git:

```bash
# Use environment variables
export TF_VAR_do_token="your-token"
export TF_VAR_smtp_password="your-password"

# Or use separate secrets file
echo "do_token = \"your-token\"" > secrets.tfvars
terraform apply -var-file=secrets.tfvars
```

### 2. Network Security

```hcl
# Restrict access by IP
ssh_allowed_ips = ["office-ip/32"]
monitoring_allowed_ips = ["office-ip/32", "vpn-range/24"]

# Use firewall rules
expose_prometheus   = false  # Don't expose internally
expose_alertmanager = false
```

### 3. State Security

```bash
# Encrypt state file
terraform {
  backend "s3" {
    encrypt = true
    # ... other config
  }
}
```

## Cost Optimization

### Resource Sizing

| Usage | Droplet Size | Cost/Month | Websites |
|-------|-------------|------------|----------|
| Testing | s-1vcpu-1gb | $6 | 1-5 |
| Small | s-2vcpu-2gb | $18 | 5-20 |
| **Recommended** | **s-2vcpu-4gb** | **$24** | **20-50** |
| Large | s-4vcpu-8gb | $48 | 50-100 |

### Cost-Saving Tips

1. **Use Reserved IPs** - Avoid IP changes
2. **Optimize retention** - Reduce data storage
3. **Schedule scaling** - Reduce size during low traffic
4. **Use Spaces** - Cheaper than block storage

## Troubleshooting

### Common Issues

**Provider authentication failed**:
```bash
export DIGITALOCEAN_TOKEN="your-token"
# Or add to terraform.tfvars
```

**Resource already exists**:
```bash
terraform import digitalocean_droplet.observability <droplet-id>
```

**State lock error**:
```bash
terraform force-unlock <lock-id>
```

### Debugging

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Check droplet logs
ssh root@<droplet-ip>
journalctl -u observability-stack -f
docker-compose logs -f
```

## Integration with CI/CD

### GitHub Actions

```yaml
name: Deploy Observability Stack

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - uses: hashicorp/setup-terraform@v1

      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform

      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: ./terraform
        env:
          TF_VAR_do_token: ${{ secrets.DO_TOKEN }}
```

### GitLab CI

```yaml
deploy:
  image: hashicorp/terraform:1.0
  script:
    - cd terraform
    - terraform init
    - terraform apply -auto-approve
  variables:
    TF_VAR_do_token: $DO_TOKEN
  only:
    - main
```

## Next Steps

1. **Review security settings** in terraform.tfvars
2. **Configure alerting** channels (email, Slack)
3. **Add custom dashboards** to Grafana
4. **Set up automated backups**
5. **Configure SSL** if using custom domain
6. **Review and adjust** resource sizing

## Support

- Terraform Documentation: https://www.terraform.io/docs
- DigitalOcean Provider: https://registry.terraform.io/providers/digitalocean/digitalocean/latest
- Issue Tracker: Create issue in your repository