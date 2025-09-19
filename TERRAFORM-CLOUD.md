# Terraform Cloud Deployment Guide

Deploy your observability stack using Terraform Cloud - no local installation required!

## Why Terraform Cloud?

- **No local installation** - Everything runs in the cloud
- **State management** - Automatic, secure state storage
- **Team collaboration** - Share infrastructure management
- **Secrets management** - Secure variable storage
- **Run history** - Track all changes
- **GitOps workflow** - Deploy via Git commits

## Quick Start (5 Minutes)

### 1. Create Terraform Cloud Account (Free)

1. Go to https://app.terraform.io/signup
2. Create your account
3. Create an organization (e.g., "my-company")

### 2. Create Workspace

1. Click "New Workspace"
2. Choose "Version control workflow"
3. Connect to GitHub/GitLab/Bitbucket
4. Select this repository
5. Name it: `observability-stack`

### 3. Configure Variables

In your workspace, go to "Variables" and add:

#### Environment Variables:
- `DIGITALOCEAN_TOKEN` - Your DigitalOcean API token (mark as sensitive)

#### Terraform Variables:
```hcl
alert_email = "your-email@example.com"
droplet_size = "s-2vcpu-4gb"
region = "nyc3"
websites_to_monitor = [
  { url = "https://example.com", label = "Main Site" }
]
```

### 4. Update Backend Configuration

Edit `terraform/backend.tf`:
```hcl
terraform {
  cloud {
    organization = "YOUR-ORG-NAME"  # Replace with your org
    workspaces {
      name = "observability-stack"
    }
  }
}
```

### 5. Deploy

**Option A: Via GitHub (Recommended)**
```bash
git add .
git commit -m "Deploy observability stack"
git push
```
The GitHub Action will automatically deploy!

**Option B: Via Terraform Cloud UI**
1. Go to your workspace
2. Click "Actions" → "Start new run"
3. Review plan
4. Click "Confirm & Apply"

## Alternative: Using Terraform Cloud CLI

If you prefer command line but don't want local Terraform:

### 1. Get API Token
1. Go to https://app.terraform.io/settings/tokens
2. Create an API token
3. Save it securely

### 2. Use Cloud Shell or GitHub Codespaces

**GitHub Codespaces:**
```bash
# Create a new codespace for this repo
# Terraform is pre-installed in Codespaces!

# Login to Terraform Cloud
terraform login
# Paste your API token when prompted

# Deploy
cd terraform
terraform init
terraform plan
terraform apply
```

**Google Cloud Shell:**
```bash
# Go to https://shell.cloud.google.com
# Terraform is pre-installed!

# Clone your repo
git clone https://github.com/yourusername/vigilant-umbrella.git
cd vigilant-umbrella/terraform

# Login to Terraform Cloud
terraform login

# Deploy
terraform init
terraform plan
terraform apply
```

## GitHub Actions Workflow

The included workflow (`.github/workflows/terraform-cloud.yml`) provides:

- **Automatic deployment** on push to main
- **Plan preview** on pull requests
- **Manual deployment** via GitHub UI
- **Destroy option** for cleanup

### Setup GitHub Actions:

1. Go to your repo Settings → Secrets
2. Add secret: `TF_API_TOKEN` (your Terraform Cloud token)
3. Push to main branch to trigger deployment

### Manual Trigger:
1. Go to Actions tab in GitHub
2. Select "Deploy via Terraform Cloud"
3. Click "Run workflow"
4. Choose action: plan/apply/destroy

## Managing Your Stack

### View Infrastructure
- Terraform Cloud UI: https://app.terraform.io
- See all resources, outputs, and state

### Get Credentials
After deployment, in Terraform Cloud:
1. Go to your workspace
2. Click "Outputs" tab
3. Find `grafana_password` (click to reveal)

### Update Configuration
1. Edit variables in Terraform Cloud UI
2. Or update `terraform.tfvars` and push to Git
3. Changes auto-deploy on merge to main

### Add Websites to Monitor
1. Go to Variables in Terraform Cloud
2. Edit `websites_to_monitor`
3. Add new sites:
   ```hcl
   [
     { url = "https://site1.com", label = "Site 1" },
     { url = "https://site2.com", label = "Site 2" }
   ]
   ```
4. Click "Save variable"
5. Queue new plan → Apply

## Cost Management

### Terraform Cloud Pricing
- **Free tier**: Up to 5 users
- Includes 500 free runs per month
- Perfect for small teams

### DigitalOcean Costs
- Droplet: $24/month (recommended size)
- Reserved IP: Free when attached
- Backups: ~$5/month (optional)

## Troubleshooting

### Common Issues

**"No configuration files found"**
- Ensure Working Directory is set to `/terraform` in workspace settings

**"Error acquiring state lock"**
- Someone else is running a plan
- Wait or force unlock in UI

**"Invalid DigitalOcean token"**
- Check token in Variables
- Ensure it's marked as environment variable
- Name must be `DIGITALOCEAN_TOKEN`

### Viewing Logs
1. Go to workspace → Runs
2. Click on any run
3. View detailed logs for each step

## Security Best Practices

1. **Never commit secrets** - Use Terraform Cloud variables
2. **Enable 2FA** on Terraform Cloud account
3. **Restrict workspace permissions** to team members
4. **Use sensitive variables** for passwords and tokens
5. **Enable run approval** for production workspaces

## Advanced Features

### Multi-Environment Setup

Create multiple workspaces:
- `observability-dev`
- `observability-staging`
- `observability-prod`

Each with different variables:
```hcl
# Dev workspace
droplet_size = "s-1vcpu-1gb"
environment = "dev"

# Prod workspace
droplet_size = "s-4vcpu-8gb"
environment = "production"
```

### Notifications

Configure in Workspace Settings → Notifications:
- Slack
- Email
- Webhooks
- Microsoft Teams

### Policy as Code (Sentinel)

Add policies to enforce:
- Approved droplet sizes only
- Required tags
- Security group rules
- Cost limits

## Quick Commands Reference

```bash
# If using CLI with Terraform Cloud

# Login
terraform login

# Initialize
cd terraform
terraform init

# Plan
terraform plan

# Apply
terraform apply

# Destroy (cleanup)
terraform destroy

# Get outputs
terraform output
terraform output -raw grafana_password
```

## Next Steps

1. ✅ Create Terraform Cloud account
2. ✅ Set up workspace
3. ✅ Add variables
4. ✅ Deploy via UI or Git push
5. 📊 Access Grafana and configure
6. 🔔 Set up alert channels
7. 📈 Add custom dashboards

## Support

- Terraform Cloud Docs: https://www.terraform.io/cloud-docs
- DigitalOcean Provider: https://registry.terraform.io/providers/digitalocean/digitalocean
- GitHub Actions: https://docs.github.com/actions