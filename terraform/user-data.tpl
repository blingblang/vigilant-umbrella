#!/bin/bash
set -e

echo "Starting observability stack deployment..."

# Update system
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install required packages
DEBIAN_FRONTEND=noninteractive apt-get install -y apache2-utils ufw certbot python3-certbot-nginx

# Clone the complete repository instead of creating files manually
cd /opt
git clone https://github.com/blingblang/vigilant-umbrella.git observability-stack
cd /opt/observability-stack

# The repository already contains all configuration files
# Just add any custom websites to monitor
%{ for website in websites_to_monitor ~}
echo "  - ${website.url}" >> prometheus/websites.txt
%{ endfor ~}

# Create .env file
cat > .env << ENV_EOF
GRAFANA_USER=admin
GRAFANA_PASSWORD=${grafana_password}
ENV_EOF

# Create htpasswd file
htpasswd -b -c nginx/htpasswd admin "${grafana_password}"

# Configure firewall
ufw --force disable
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp
ufw allow 9090/tcp
ufw allow 9093/tcp
ufw allow 9100/tcp
ufw allow 9115/tcp
ufw allow 8080/tcp
ufw --force enable

# Setup SSL if enabled
%{ if enable_ssl ~}
if [ ! -z "${domain_name}" ] && [ ! -z "${letsencrypt_email}" ]; then
    certbot certonly --standalone -d ${subdomain}.${domain_name} --email ${letsencrypt_email} --agree-tos --non-interactive

    # Update Nginx configuration for SSL
    cat > nginx/nginx-ssl.conf << 'SSL_EOF'
events {
    worker_connections 1024;
}

http {
    upstream grafana {
        server grafana:3000;
    }

    server {
        listen 80;
        server_name ${subdomain}.${domain_name};
        return 301 https://$$server_name$$request_uri;
    }

    server {
        listen 443 ssl;
        server_name ${subdomain}.${domain_name};

        ssl_certificate /etc/letsencrypt/live/${subdomain}.${domain_name}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${subdomain}.${domain_name}/privkey.pem;

        location / {
            proxy_pass http://grafana;
            proxy_set_header Host $$host;
            proxy_set_header X-Real-IP $$remote_addr;
            proxy_set_header X-Forwarded-For $$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $$scheme;
        }
    }
}
SSL_EOF

    # Use SSL config if certificate obtained
    if [ -f /etc/letsencrypt/live/${subdomain}.${domain_name}/fullchain.pem ]; then
        mv nginx/nginx-ssl.conf nginx/nginx.conf
    fi
fi
%{ endif ~}

# Start Docker services
docker-compose pull
docker-compose up -d

# Create backup script
cat > /opt/observability-stack/backup.sh << 'BACKUP_EOF'
#!/bin/bash
BACKUP_DIR="/opt/observability-stack/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$$BACKUP_DIR"

docker run --rm -v observability-stack_prometheus_data:/data -v "$$BACKUP_DIR":/backup alpine tar czf /backup/prometheus.tar.gz -C /data .
docker run --rm -v observability-stack_grafana_data:/data -v "$$BACKUP_DIR":/backup alpine tar czf /backup/grafana.tar.gz -C /data .
docker run --rm -v observability-stack_alertmanager_data:/data -v "$$BACKUP_DIR":/backup alpine tar czf /backup/alertmanager.tar.gz -C /data .

echo "Backup completed: $$BACKUP_DIR"
BACKUP_EOF

chmod +x /opt/observability-stack/backup.sh

# Create cron job for daily backups
echo "0 2 * * * /opt/observability-stack/backup.sh" | crontab -

# Create systemd service for auto-start
cat > /etc/systemd/system/observability-stack.service << 'SERVICE_EOF'
[Unit]
Description=Observability Stack
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/observability-stack
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable observability-stack

echo "Observability stack deployment completed!"