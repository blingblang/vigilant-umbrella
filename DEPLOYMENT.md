# Deploying Observability Stack on DigitalOcean

This guide will help you deploy a complete observability stack (Grafana, Prometheus, Alertmanager) on a DigitalOcean Droplet.

## Prerequisites

- DigitalOcean account
- SSH key configured in DigitalOcean
- Local machine with SSH client

## Option 1: Deploy to Existing Droplet (Recommended)

If you already have a DigitalOcean Droplet running Ubuntu 20.04+ or similar:

### Step 1: Run Deployment Script

```bash
chmod +x digitalocean-setup.sh
./digitalocean-setup.sh
```

You'll be prompted for:
- Your Droplet's IP address
- Grafana admin password
- Email for alerts
- Optional Slack webhook URL

The script will:
1. Connect to your droplet via SSH
2. Install Docker and Docker Compose
3. Deploy the complete observability stack
4. Configure firewall rules
5. Start all services

### Step 2: Access Services

After deployment, access your services:
- **Grafana**: `http://your-droplet-ip:3000`
- **Prometheus**: `http://your-droplet-ip:9090`
- **Alertmanager**: `http://your-droplet-ip:9093`

## Option 2: Create New Droplet with doctl

If you need to create a new droplet:

### Step 1: Install doctl

```bash
# macOS
brew install doctl

# Linux (snap)
snap install doctl

# Or download from: https://docs.digitalocean.com/reference/doctl/how-to/install/
```

### Step 2: Configure doctl

```bash
doctl auth init
# Enter your DigitalOcean API token
```

### Step 3: Create Droplet and Deploy

```bash
chmod +x create-droplet.sh
./create-droplet.sh
```

This script will:
1. Create a new DigitalOcean Droplet
2. Configure it with the observability stack
3. Set up all services automatically

## Managing Your Stack

### Remote Management Tool

Use the remote management script to control your stack:

```bash
chmod +x remote-manage.sh
./remote-manage.sh your-droplet-ip
```

Available operations:
- View service status and logs
- Add/list monitored websites
- Restart/update services
- Backup data volumes
- Edit configurations
- Monitor resource usage

### Adding Websites to Monitor

#### Method 1: Using Remote Manager
```bash
./remote-manage.sh your-droplet-ip
# Choose option 6: Add website to monitor
```

#### Method 2: Manual Edit
1. SSH into your droplet: `ssh root@your-droplet-ip`
2. Edit Prometheus config: `nano /opt/observability-stack/prometheus/prometheus.yml`
3. Add your website under the `blackbox-http` job:
   ```yaml
   - targets:
       - https://yourwebsite.com
       - https://another-site.com
   ```
4. Reload Prometheus: `docker-compose exec prometheus kill -HUP 1`

### Configuring Alerts

1. SSH into your droplet
2. Edit Alertmanager config:
   ```bash
   nano /opt/observability-stack/alertmanager/alertmanager.yml
   ```
3. Update email settings:
   - SMTP server details
   - Recipient email addresses
   - Slack webhook URL (if using Slack)
4. Reload Alertmanager:
   ```bash
   docker-compose exec alertmanager kill -HUP 1
   ```

## Security Recommendations

1. **Change default passwords immediately** after deployment
2. **Enable DigitalOcean firewall** in addition to UFW:
   ```bash
   doctl compute firewall create \
     --name observability-firewall \
     --inbound-rules "protocol:tcp,ports:22,sources:0.0.0.0/0" \
     --inbound-rules "protocol:tcp,ports:3000,sources:0.0.0.0/0" \
     --inbound-rules "protocol:tcp,ports:9090,sources:0.0.0.0/0" \
     --inbound-rules "protocol:tcp,ports:9093,sources:0.0.0.0/0"
   ```
3. **Use HTTPS** with Let's Encrypt (see nginx configuration)
4. **Regular backups** using the management script
5. **Monitor disk space** - Prometheus data grows over time

## Backup and Restore

### Creating Backups
```bash
./remote-manage.sh your-droplet-ip
# Choose option 10: Backup data volumes
```

### Restoring from Backup
```bash
ssh root@your-droplet-ip
cd /opt/observability-stack
docker-compose down
# Restore backup files from /opt/observability-stack/backups/
docker-compose up -d
```

## Troubleshooting

### Check Service Status
```bash
ssh root@your-droplet-ip
cd /opt/observability-stack
docker-compose ps
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f grafana
docker-compose logs -f prometheus
docker-compose logs -f alertmanager
```

### Restart Services
```bash
docker-compose restart
```

### Common Issues

1. **Services not starting**: Check disk space with `df -h`
2. **Cannot access Grafana**: Verify firewall rules with `ufw status`
3. **Alerts not sending**: Check Alertmanager logs and email configuration
4. **High memory usage**: Consider upgrading droplet size
5. **Websites showing as down**: Verify Blackbox Exporter can reach external URLs

## Monitoring Best Practices

1. **Set up meaningful alerts** - Don't alert on everything
2. **Use Grafana folders** to organize dashboards by service/website
3. **Configure data retention** based on your needs (default: 30 days)
4. **Regular updates** - Keep all components up to date
5. **Monitor the monitors** - Ensure your observability stack is healthy

## Cost Optimization

- **Droplet sizing**: Start with s-2vcpu-4gb ($24/month) and scale as needed
- **Data retention**: Reduce retention period to save disk space
- **Snapshots**: Use DigitalOcean snapshots for backups instead of volumes
- **Reserved IPs**: Use a reserved IP if you need to recreate droplets

## Support

- Check logs first: `docker-compose logs`
- DigitalOcean community: https://www.digitalocean.com/community
- Grafana docs: https://grafana.com/docs/
- Prometheus docs: https://prometheus.io/docs/