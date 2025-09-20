# Migration Guide: Local to Centralized Monitoring

This guide helps you migrate from local Prometheus/Grafana instances to your centralized observability stack at **159.89.243.148**.

## Your Centralized Stack Access

- **Grafana**: http://159.89.243.148:3000
- **Prometheus**: http://159.89.243.148:9090
- **Alertmanager**: http://159.89.243.148:9093
- **SSH**: `ssh root@159.89.243.148`

## Migration Strategies

### Strategy 1: Remote Scraping (Recommended)
Keep exporters running on your sites, centralized Prometheus scrapes them remotely.

**Pros:**
- Minimal changes to existing sites
- Can migrate gradually
- Keep local metrics as backup

**Cons:**
- Requires open ports or VPN
- Network latency affects scraping

### Strategy 2: Push Gateway
Sites push metrics to centralized Prometheus via Push Gateway.

**Pros:**
- No open ports needed on sites
- Works through firewalls
- Good for batch jobs

**Cons:**
- Requires code changes
- Less real-time

### Strategy 3: Remote Write
Local Prometheus forwards metrics to central one.

**Pros:**
- Keep local Prometheus as buffer
- No data loss during network issues
- Gradual migration

**Cons:**
- Requires Prometheus on each site
- More complex setup

## Step-by-Step Migration

### Phase 1: Inventory Your Sites

Create a list of all your sites with:
- Site name and URL
- Current metrics endpoints
- Exporters running (node_exporter, etc.)
- Custom metrics/dashboards
- Alert rules

### Phase 2: Configure Central Prometheus

SSH into your droplet and add remote scraping:

```bash
ssh root@159.89.243.148
cd /opt/observability-stack
nano prometheus/prometheus.yml
```

Add your sites to the configuration:

```yaml
scrape_configs:
  # Existing configs...

  # Remote site scraping
  - job_name: 'site1-node'
    static_configs:
      - targets: ['site1.example.com:9100']
        labels:
          site: 'site1'
          environment: 'production'

  - job_name: 'site2-node'
    static_configs:
      - targets: ['site2.example.com:9100']
        labels:
          site: 'site2'
          environment: 'production'

  # Application metrics
  - job_name: 'site1-app'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['site1.example.com:8080']
        labels:
          site: 'site1'
          app: 'web-app'
```

Reload Prometheus:
```bash
docker-compose exec prometheus kill -HUP 1
```

### Phase 3: Secure Remote Endpoints

#### Option A: VPN/Private Network
Best for DigitalOcean droplets - use Private Networking:
```yaml
- targets: ['10.132.0.2:9100']  # Private IP
```

#### Option B: Basic Auth on Exporters
Configure node_exporter with basic auth:
```yaml
basic_auth:
  username: 'prometheus'
  password: 'secure-password'
```

#### Option C: Firewall Rules
Allow only your monitoring droplet:
```bash
# On each site
ufw allow from 159.89.243.148 to any port 9100
```

### Phase 4: Migrate Dashboards

1. **Export from local Grafana:**
   - Open local Grafana
   - Go to dashboard → Settings → JSON Model
   - Copy JSON

2. **Import to central Grafana:**
   - Open http://159.89.243.148:3000
   - Create → Import → Paste JSON
   - Update datasource to "Prometheus"

3. **Update queries for multi-site:**
   Add site label to distinguish metrics:
   ```promql
   # Before
   node_cpu_seconds_total

   # After
   node_cpu_seconds_total{site="site1"}
   ```

### Phase 5: Migrate Alert Rules

Copy your alert rules to central Prometheus:

```bash
ssh root@159.89.243.148
cd /opt/observability-stack
nano prometheus/alert_rules.yml
```

Add site-specific alerts:
```yaml
- name: site1_alerts
  rules:
    - alert: Site1_Down
      expr: up{job="site1-node"} == 0
      for: 1m
      labels:
        severity: critical
        site: site1
      annotations:
        summary: "Site1 node exporter is down"

    - alert: Site1_HighCPU
      expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle",site="site1"}[5m])) * 100) > 80
      for: 5m
      labels:
        severity: warning
        site: site1
```

### Phase 6: Test & Validate

1. **Verify metrics collection:**
   ```
   http://159.89.243.148:9090/targets
   ```
   All targets should be "UP"

2. **Check dashboards:**
   - Open Grafana
   - Verify data is flowing
   - Test time ranges

3. **Test alerts:**
   - Stop a service temporarily
   - Verify alert fires
   - Check notification delivery

### Phase 7: Decommission Local Instances

Once validated, on each site:

```bash
# Stop local Prometheus/Grafana
docker-compose stop prometheus grafana

# Keep exporters running
docker-compose up -d node-exporter

# Remove local data (after backup!)
docker volume rm site_prometheus_data site_grafana_data
```

## Migration Scripts

### Script 1: Add Site to Central Monitoring

Create `add-site.sh`:

```bash
#!/bin/bash
# Usage: ./add-site.sh site-name site-ip exporter-port

SITE_NAME=$1
SITE_IP=$2
EXPORTER_PORT=${3:-9100}

ssh root@159.89.243.148 << EOF
cd /opt/observability-stack

# Backup current config
cp prometheus/prometheus.yml prometheus/prometheus.yml.bak

# Add new site
cat >> prometheus/prometheus.yml << CONFIG

  - job_name: '${SITE_NAME}-node'
    static_configs:
      - targets: ['${SITE_IP}:${EXPORTER_PORT}']
        labels:
          site: '${SITE_NAME}'
          environment: 'production'
CONFIG

# Reload Prometheus
docker-compose exec -T prometheus kill -HUP 1

echo "Added ${SITE_NAME} to monitoring"
EOF
```

### Script 2: Bulk Migration

Create `migrate-sites.sh`:

```bash
#!/bin/bash

# List of sites to migrate
SITES=(
  "site1,site1.example.com,9100"
  "site2,site2.example.com,9100"
  "site3,10.132.0.3,9100"  # Private IP
)

for site in "${SITES[@]}"; do
  IFS=',' read -r name ip port <<< "$site"
  ./add-site.sh "$name" "$ip" "$port"
  echo "Migrated: $name"
  sleep 2
done
```

### Script 3: Export All Dashboards

On local Grafana:

```bash
#!/bin/bash
# export-dashboards.sh

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"
OUTPUT_DIR="./dashboard-exports"

mkdir -p $OUTPUT_DIR

# Get all dashboards
DASHBOARDS=$(curl -s -u $GRAFANA_USER:$GRAFANA_PASS \
  $GRAFANA_URL/api/search?type=dash-db | jq -r '.[] | .uid')

for uid in $DASHBOARDS; do
  echo "Exporting dashboard: $uid"
  curl -s -u $GRAFANA_USER:$GRAFANA_PASS \
    $GRAFANA_URL/api/dashboards/uid/$uid \
    | jq '.dashboard' > "$OUTPUT_DIR/${uid}.json"
done

echo "Dashboards exported to $OUTPUT_DIR"
```

## Remote Write Configuration

If keeping local Prometheus as buffer:

On each site's `prometheus.yml`:

```yaml
remote_write:
  - url: "http://159.89.243.148:9090/api/v1/write"
    remote_timeout: 30s
    queue_config:
      capacity: 10000
      max_samples_per_send: 5000
      batch_send_deadline: 5s
      max_retries: 10
      min_backoff: 30ms
      max_backoff: 100ms
```

## Push Gateway Setup

If sites can't be scraped directly:

```bash
# On central droplet
docker-compose exec -it prometheus sh
cat >> /etc/prometheus/prometheus.yml << EOF

  - job_name: 'pushgateway'
    static_configs:
      - targets: ['pushgateway:9091']
EOF
```

From your sites, push metrics:

```bash
# Push custom metrics
echo "site1_custom_metric 42" | curl --data-binary @- \
  http://159.89.243.148:9091/metrics/job/site1/instance/web01
```

## Monitoring the Migration

Create a migration dashboard in Grafana:

1. **Migration Progress:**
   ```promql
   count(up{job=~"site.*"} == 1)  # Sites successfully migrated
   ```

2. **Scrape Performance:**
   ```promql
   prometheus_target_scrape_duration_seconds  # Latency to sites
   ```

3. **Data Completeness:**
   ```promql
   rate(prometheus_tsdb_samples_appended_total[5m])  # Ingestion rate
   ```

## Rollback Plan

If issues arise:

1. **Keep local Prometheus running** initially (just stop Grafana)
2. **Dual-write metrics** to both local and central
3. **Test thoroughly** before decommissioning
4. **Backup local data** before removal

```bash
# Backup Prometheus data
docker run --rm -v site_prometheus_data:/data \
  -v $(pwd):/backup alpine \
  tar czf /backup/prometheus-backup.tar.gz /data
```

## Troubleshooting

### Issue: Cannot reach site exporters
```bash
# Test connectivity from droplet
ssh root@159.89.243.148
curl -v telnet://site1.example.com:9100
```

### Issue: High scrape latency
- Consider regional deployment
- Use remote_write instead
- Increase scrape_interval

### Issue: Too many metrics
- Use metric_relabeling to drop unnecessary metrics
- Implement recording rules for aggregation
- Consider federation for large scale

## Best Practices

1. **Label everything** with site/environment
2. **Use service discovery** when possible
3. **Monitor the monitors** - alert on scrape failures
4. **Implement retention policies** based on importance
5. **Document your setup** for team members

## Next Steps

1. Start with one non-critical site
2. Validate all metrics and dashboards work
3. Migrate sites in batches
4. Update documentation and runbooks
5. Train team on new central system

## Support Commands

Quick reference for your central stack:

```bash
# SSH to monitoring droplet
ssh root@159.89.243.148

# View logs
docker-compose logs -f prometheus

# Reload configuration
docker-compose exec prometheus kill -HUP 1

# Check targets
curl http://159.89.243.148:9090/api/v1/targets

# Backup data
./backup.sh

# Add new site
./remote-manage.sh 159.89.243.148
```