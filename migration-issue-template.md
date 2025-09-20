# Migrate to Centralized Observability Stack

## Overview
This repository currently has local Prometheus and Grafana configuration. We need to migrate it to use our centralized observability stack instead.

**Central Monitoring Stack:**
- **Droplet IP**: 159.89.243.148
- **Grafana**: http://159.89.243.148:3000
- **Prometheus**: http://159.89.243.148:9090
- **Alertmanager**: http://159.89.243.148:9093

## Migration Tasks

### 1. Remove Local Observability Components

Remove the following from this repository:
- [ ] Local Prometheus configuration (`prometheus.yml`, `prometheus/`)
- [ ] Local Grafana configuration (`grafana/`)
- [ ] Alertmanager configuration (if present)
- [ ] Docker Compose services for `prometheus`, `grafana`, `alertmanager`
- [ ] Any local volume definitions for monitoring data
- [ ] Monitoring-related environment variables in `.env` files

### 2. Keep/Configure Exporters

Keep these components running (they'll be scraped by central Prometheus):
- [ ] `node-exporter` (if present) - Keep running on port 9100
- [ ] Application metrics endpoints (if present) - Keep exposed
- [ ] Any custom exporters specific to this application

### 3. Update Docker Compose

Modify `docker-compose.yml`:
```yaml
# Remove these services:
# - prometheus
# - grafana
# - alertmanager

# Keep these (example):
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    restart: unless-stopped
    # ... existing configuration

  # Your application services remain unchanged
  app:
    # ... your app configuration
```

### 4. Configure Firewall Access

If this service is hosted on a server, allow the central monitor to scrape metrics:

```bash
# Allow central monitor to access node-exporter
ufw allow from 159.89.243.148 to any port 9100

# If you have app metrics on a different port
ufw allow from 159.89.243.148 to any port <your-metrics-port>
```

### 5. Register with Central Monitoring

Add this service to the central Prometheus configuration. The service needs to be added with:

**Service Details Needed:**
- Service name: `[repository-name]`
- Host/IP: `[where-this-service-runs]`
- Node exporter port: `9100` (if applicable)
- App metrics port: `[if-applicable]`
- Environment: `production/staging/dev`

**Configuration to add to central Prometheus:**
```yaml
  - job_name: '[repository-name]-node'
    static_configs:
      - targets: ['[host]:9100']
        labels:
          site: '[repository-name]'
          environment: 'production'

  # If app has metrics endpoint
  - job_name: '[repository-name]-app'
    metrics_path: '/metrics'  # or your metrics path
    static_configs:
      - targets: ['[host]:[app-port]']
        labels:
          site: '[repository-name]'
          app: '[app-name]'
          environment: 'production'
```

### 6. Migrate Dashboards

If this repository has custom Grafana dashboards:
1. Export them from local Grafana (JSON format)
2. Import to central Grafana at http://159.89.243.148:3000
3. Update queries to filter by site label: `{site="[repository-name]"}`

### 7. Update Documentation

- [ ] Update README.md to remove local monitoring setup instructions
- [ ] Add section about central monitoring:
  ```markdown
  ## Monitoring
  This service is monitored via our central observability stack.
  - Grafana dashboards: http://159.89.243.148:3000
  - Metrics are scraped from port 9100 (node) and [app-port] (application)
  ```

### 8. Clean Up

After verification:
- [ ] Remove unused monitoring volumes: `docker volume prune`
- [ ] Remove monitoring-related secrets/configs from `.env`
- [ ] Delete local monitoring data directories
- [ ] Update `.gitignore` to remove monitoring paths

## Testing Checklist

- [ ] Node exporter is accessible on port 9100
- [ ] Application metrics (if any) are accessible
- [ ] Central Prometheus can reach this service (check http://159.89.243.148:9090/targets)
- [ ] Metrics appear in central Grafana
- [ ] No local Prometheus/Grafana containers running
- [ ] Application still works correctly without local monitoring

## Files for Reference

See attached files in comments below:
- `MIGRATION-GUIDE.md` - Detailed migration instructions
- `configure-site-exporters.sh` - Script to configure exporters
- `add-remote-site.sh` - Script to add site to central monitoring

## Success Criteria

✅ Migration is complete when:
1. No local Prometheus/Grafana/Alertmanager running
2. Service registered in central monitoring
3. Metrics visible in central Grafana
4. All monitoring data consolidated in central stack
5. Documentation updated

## Questions/Support

If you need the central monitoring credentials or have questions, please comment on this issue.