#!/bin/bash

set -e

echo "Remote Observability Stack Manager"
echo "=================================="
echo ""

# Check if IP is provided as argument or ask for it
if [ -n "$1" ]; then
    DROPLET_IP="$1"
else
    read -p "Enter your DigitalOcean Droplet IP: " DROPLET_IP
fi

if [ -z "$DROPLET_IP" ]; then
    echo "Error: IP address is required"
    exit 1
fi

SSH_USER=${SSH_USER:-root}

function show_menu() {
    echo ""
    echo "What would you like to do?"
    echo "=========================="
    echo "1)  View service status"
    echo "2)  View logs (all services)"
    echo "3)  View Grafana logs"
    echo "4)  View Prometheus logs"
    echo "5)  View Alertmanager logs"
    echo "6)  Add website to monitor"
    echo "7)  List monitored websites"
    echo "8)  Restart all services"
    echo "9)  Update services to latest versions"
    echo "10) Backup data volumes"
    echo "11) Show disk usage"
    echo "12) Show resource usage"
    echo "13) Edit Prometheus config"
    echo "14) Edit Alertmanager config"
    echo "15) Reload Prometheus config"
    echo "16) Reload Alertmanager config"
    echo "17) Stop all services"
    echo "18) Start all services"
    echo "19) Open shell on droplet"
    echo "0)  Exit"
    echo ""
    read -p "Enter choice [0-19]: " choice
}

function remote_exec() {
    ssh $SSH_USER@$DROPLET_IP "$1"
}

function view_status() {
    echo "Fetching service status..."
    remote_exec "cd /opt/observability-stack && docker-compose ps"
}

function view_logs() {
    echo "Fetching logs (press Ctrl+C to stop)..."
    ssh -t $SSH_USER@$DROPLET_IP "cd /opt/observability-stack && docker-compose logs -f --tail=100"
}

function view_grafana_logs() {
    echo "Fetching Grafana logs (press Ctrl+C to stop)..."
    ssh -t $SSH_USER@$DROPLET_IP "cd /opt/observability-stack && docker-compose logs -f grafana --tail=100"
}

function view_prometheus_logs() {
    echo "Fetching Prometheus logs (press Ctrl+C to stop)..."
    ssh -t $SSH_USER@$DROPLET_IP "cd /opt/observability-stack && docker-compose logs -f prometheus --tail=100"
}

function view_alertmanager_logs() {
    echo "Fetching Alertmanager logs (press Ctrl+C to stop)..."
    ssh -t $SSH_USER@$DROPLET_IP "cd /opt/observability-stack && docker-compose logs -f alertmanager --tail=100"
}

function add_website() {
    read -p "Enter website URL to monitor (e.g., https://example.com): " url
    read -p "Enter a label for this website: " label

    if [ -z "$url" ] || [ -z "$label" ]; then
        echo "Error: Both URL and label are required"
        return
    fi

    echo "Adding $url to monitoring..."

    # Create a temporary script to add the website
    cat > /tmp/add_website.sh << EOF
#!/bin/bash
cd /opt/observability-stack

# Backup current config
cp prometheus/prometheus.yml prometheus/prometheus.yml.backup

# Add website to the blackbox-http job
sed -i '/job_name: .blackbox-http/,/job_name:/{
    /static_configs:/,/- targets:/{
        /- targets:/a\          - $url
    }
}' prometheus/prometheus.yml

# Reload Prometheus
docker-compose exec -T prometheus kill -HUP 1

echo "Website added successfully!"
EOF

    # Copy and execute the script
    scp /tmp/add_website.sh $SSH_USER@$DROPLET_IP:/tmp/
    remote_exec "bash /tmp/add_website.sh && rm /tmp/add_website.sh"
    rm /tmp/add_website.sh
}

function list_websites() {
    echo "Currently monitored websites:"
    echo "============================="
    remote_exec "cd /opt/observability-stack && grep -A 20 'job_name: .blackbox-http' prometheus/prometheus.yml | grep -E '^\s+-\s+https?://' | sed 's/^[ \t]*- //'"
}

function restart_services() {
    echo "Restarting all services..."
    remote_exec "cd /opt/observability-stack && docker-compose restart"
    echo "Services restarted successfully"
}

function update_services() {
    echo "Updating services to latest versions..."
    remote_exec "cd /opt/observability-stack && docker-compose pull && docker-compose up -d"
    echo "Services updated successfully"
}

function backup_data() {
    BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
    echo "Creating backup: $BACKUP_NAME"

    remote_exec "cd /opt/observability-stack && mkdir -p backups && \
        docker run --rm -v observability-stack_prometheus_data:/data -v /opt/observability-stack/backups:/backup alpine \
        tar czf /backup/${BACKUP_NAME}-prometheus.tar.gz -C /data . && \
        docker run --rm -v observability-stack_grafana_data:/data -v /opt/observability-stack/backups:/backup alpine \
        tar czf /backup/${BACKUP_NAME}-grafana.tar.gz -C /data . && \
        docker run --rm -v observability-stack_alertmanager_data:/data -v /opt/observability-stack/backups:/backup alpine \
        tar czf /backup/${BACKUP_NAME}-alertmanager.tar.gz -C /data ."

    echo "Backup created successfully at /opt/observability-stack/backups/$BACKUP_NAME-*.tar.gz"

    read -p "Download backup to local machine? (y/n): " download
    if [ "$download" = "y" ]; then
        mkdir -p ./backups
        scp $SSH_USER@$DROPLET_IP:/opt/observability-stack/backups/${BACKUP_NAME}-*.tar.gz ./backups/
        echo "Backup downloaded to ./backups/"
    fi
}

function show_disk_usage() {
    echo "Disk usage on droplet:"
    remote_exec "df -h"
    echo ""
    echo "Docker volume sizes:"
    remote_exec "docker system df"
}

function show_resource_usage() {
    echo "Resource usage:"
    remote_exec "echo '=== CPU and Memory ===' && top -bn1 | head -20 && echo '' && echo '=== Docker Stats ===' && docker stats --no-stream"
}

function edit_prometheus_config() {
    echo "Opening Prometheus configuration..."
    ssh -t $SSH_USER@$DROPLET_IP "nano /opt/observability-stack/prometheus/prometheus.yml"
}

function edit_alertmanager_config() {
    echo "Opening Alertmanager configuration..."
    ssh -t $SSH_USER@$DROPLET_IP "nano /opt/observability-stack/alertmanager/alertmanager.yml"
}

function reload_prometheus() {
    echo "Reloading Prometheus configuration..."
    remote_exec "cd /opt/observability-stack && docker-compose exec -T prometheus kill -HUP 1"
    echo "Prometheus configuration reloaded"
}

function reload_alertmanager() {
    echo "Reloading Alertmanager configuration..."
    remote_exec "cd /opt/observability-stack && docker-compose exec -T alertmanager kill -HUP 1"
    echo "Alertmanager configuration reloaded"
}

function stop_services() {
    echo "Stopping all services..."
    remote_exec "cd /opt/observability-stack && docker-compose down"
    echo "Services stopped"
}

function start_services() {
    echo "Starting all services..."
    remote_exec "cd /opt/observability-stack && docker-compose up -d"
    echo "Services started"
}

function open_shell() {
    echo "Opening shell on droplet..."
    ssh -t $SSH_USER@$DROPLET_IP
}

# Main loop
while true; do
    show_menu
    case $choice in
        1) view_status ;;
        2) view_logs ;;
        3) view_grafana_logs ;;
        4) view_prometheus_logs ;;
        5) view_alertmanager_logs ;;
        6) add_website ;;
        7) list_websites ;;
        8) restart_services ;;
        9) update_services ;;
        10) backup_data ;;
        11) show_disk_usage ;;
        12) show_resource_usage ;;
        13) edit_prometheus_config ;;
        14) edit_alertmanager_config ;;
        15) reload_prometheus ;;
        16) reload_alertmanager ;;
        17) stop_services ;;
        18) start_services ;;
        19) open_shell ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid choice!" ;;
    esac

    if [ "$choice" != "0" ]; then
        echo ""
        read -p "Press Enter to continue..."
    fi
done