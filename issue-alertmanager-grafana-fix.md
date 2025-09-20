# Fix AlertManager Port Access and Reset Grafana Password

## Current Status
The observability stack is deployed on DigitalOcean droplet **159.89.243.148** with most services working, but two critical issues need resolution:

1. **AlertManager** (port 9093) is not accessible externally
2. **Grafana** admin password is not working with the configured credentials

## Issue 1: AlertManager Port 9093 Not Accessible

### Current Situation
- AlertManager container is running: ✅
- Port 9093 should be accessible but connection is refused
- Prometheus (9090) is working after firewall fix was applied

### Diagnostic Commands to Run
```bash
# SSH to droplet (use DigitalOcean web console)
ssh root@159.89.243.148
cd /opt/observability-stack

# Check AlertManager status
docker-compose ps alertmanager

# Check if port is listening
netstat -tuln | grep 9093

# Test local connectivity
curl -I http://localhost:9093

# Check AlertManager logs
docker-compose logs alertmanager --tail 50

# Check Docker port binding
docker port alertmanager
```

### Potential Fixes

#### Fix A: Check Docker Compose Port Mapping
Verify in `docker-compose.yml` that AlertManager has correct port mapping:
```yaml
alertmanager:
  ports:
    - "9093:9093"
```

#### Fix B: Verify UFW Firewall
```bash
# Check if port is allowed
ufw status | grep 9093

# If not present, add it
ufw allow 9093/tcp
ufw reload
```

#### Fix C: Check DigitalOcean Firewall
- Go to DigitalOcean Dashboard → Networking → Firewalls
- Firewall ID: `f0759c5c-c8bd-4695-95a5-e781d408a995`
- Verify port 9093 is in inbound rules
- If not, the Terraform configuration already has it, so re-run Terraform apply

#### Fix D: Check AlertManager Config
```bash
# Verify config file exists and is valid
cat alertmanager/alertmanager.yml

# If missing or invalid, create minimal config:
cat > alertmanager/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'

receivers:
  - name: 'default'
EOF

# Restart AlertManager
docker-compose restart alertmanager
```

## Issue 2: Grafana Password Not Working

### Current Situation
- Grafana is running on port 3000: ✅
- Web interface is accessible: ✅
- Login with admin/admin123 is failing: ❌

### Root Cause
Grafana creates its own admin password database on first run, which can override the environment variables.

### Fix Instructions

```bash
# SSH to droplet
ssh root@159.89.243.148
cd /opt/observability-stack

# Method 1: Reset via Grafana CLI (Recommended)
docker-compose exec grafana grafana-cli admin reset-admin-password admin123

# Method 2: Update environment and restart
echo "GRAFANA_USER=admin" > .env
echo "GRAFANA_PASSWORD=admin123" >> .env

# Also update the nginx htpasswd
htpasswd -b -c nginx/htpasswd admin admin123

# Restart Grafana
docker-compose restart grafana

# Method 3: If above doesn't work, reset via SQLite directly
docker-compose exec grafana bash
sqlite3 /var/lib/grafana/grafana.db
UPDATE user SET password = '59acf18b94d7eb0694c61e60ce44c110c7a683ac6a8f09580d626f90f4a242000746579358d77dd9e570e83fa24faa88a8a6', salt = 'F3FAxVm33R', rands = 'NX4xTjB9IV', mtime = datetime('now') WHERE login = 'admin';
.exit
exit

# This sets password to 'admin' - change it after login
```

### Verification Steps
1. Try logging in with:
   - Username: `admin`
   - Password: `admin123` (or `admin` if using Method 3)

2. If successful, immediately change password in Grafana UI:
   - Click user icon → Preferences → Change Password

## Testing Checklist

- [ ] AlertManager accessible at http://159.89.243.148:9093
- [ ] Grafana login works with admin/admin123
- [ ] All ports show in `ufw status`:
  - 3000 (Grafana) ✅
  - 9090 (Prometheus) ✅
  - 9093 (AlertManager) ⏳
  - 9100 (Node Exporter)
  - 9115 (Blackbox Exporter)
  - 8080 (cAdvisor)

## Related Configuration Files

### Location on Droplet
- Main directory: `/opt/observability-stack/`
- Docker Compose: `/opt/observability-stack/docker-compose.yml`
- AlertManager config: `/opt/observability-stack/alertmanager/alertmanager.yml`
- Environment vars: `/opt/observability-stack/.env`
- Nginx auth: `/opt/observability-stack/nginx/htpasswd`

### Terraform Configuration (Already Updated)
- Firewall rules updated in `terraform/main.tf` (commit 83738aa)
- Port 9093 included in firewall rules
- Applied via Terraform Cloud

## Quick Test Commands

After fixes are applied:
```bash
# From your local machine, test all services:
curl -I http://159.89.243.148:3000  # Grafana
curl -I http://159.89.243.148:9090  # Prometheus
curl -I http://159.89.243.148:9093  # AlertManager

# Or use the browser:
# Grafana: http://159.89.243.148:3000 (admin/admin123)
# Prometheus: http://159.89.243.148:9090
# AlertManager: http://159.89.243.148:9093
```

## Success Criteria

✅ Issue is resolved when:
1. AlertManager web UI is accessible at http://159.89.243.148:9093
2. Grafana login works with username `admin` and password `admin123`
3. All three monitoring services (Grafana, Prometheus, AlertManager) are accessible externally

## Additional Notes

- Droplet ID: 519669280
- All services are running in Docker containers managed by Docker Compose
- The stack was manually deployed after Terraform cloud-init partially failed
- Repository: https://github.com/blingblang/vigilant-umbrella
- Related chats:
  - `chats/claude_code_chat_2025-09-20_09-11-51.md` (initial fix)
  - `chats/claude_code_chat_2025-09-20_10-46-18.md` (Terraform updates)