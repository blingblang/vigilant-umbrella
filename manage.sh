#!/bin/bash

set -e

COMMAND="${1}"

function show_help() {
    echo "Observability Stack Management Script"
    echo "======================================"
    echo ""
    echo "Usage: ./manage.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start       - Start all services"
    echo "  stop        - Stop all services"
    echo "  restart     - Restart all services"
    echo "  status      - Show service status"
    echo "  logs        - Show logs (follow mode)"
    echo "  logs-tail   - Show last 100 lines of logs"
    echo "  update      - Pull latest images and restart"
    echo "  backup      - Backup data volumes"
    echo "  restore     - Restore data volumes from backup"
    echo "  clean       - Remove all containers and volumes (WARNING: Data loss!)"
    echo "  add-website - Add a website to monitor"
    echo "  reload-prometheus - Reload Prometheus configuration"
    echo "  reload-alertmanager - Reload Alertmanager configuration"
}

function start_services() {
    echo "Starting services..."
    docker-compose up -d
    echo "Services started successfully"
}

function stop_services() {
    echo "Stopping services..."
    docker-compose down
    echo "Services stopped successfully"
}

function restart_services() {
    echo "Restarting services..."
    docker-compose restart
    echo "Services restarted successfully"
}

function show_status() {
    echo "Service Status:"
    docker-compose ps
}

function show_logs() {
    docker-compose logs -f
}

function show_logs_tail() {
    docker-compose logs --tail=100
}

function update_services() {
    echo "Pulling latest images..."
    docker-compose pull
    echo "Restarting services with new images..."
    docker-compose up -d
    echo "Update completed successfully"
}

function backup_data() {
    BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
    echo "Creating backup in $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"

    docker run --rm -v vigilant-umbrella_prometheus_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/prometheus_data.tar.gz -C /data .
    docker run --rm -v vigilant-umbrella_grafana_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/grafana_data.tar.gz -C /data .
    docker run --rm -v vigilant-umbrella_alertmanager_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/alertmanager_data.tar.gz -C /data .

    echo "Backup completed successfully in $BACKUP_DIR"
}

function restore_data() {
    if [ -z "$2" ]; then
        echo "Please specify backup directory. Example: ./manage.sh restore backups/20240101_120000"
        exit 1
    fi

    BACKUP_DIR="$2"
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Backup directory $BACKUP_DIR does not exist"
        exit 1
    fi

    echo "Stopping services..."
    docker-compose down

    echo "Restoring from $BACKUP_DIR..."
    docker run --rm -v vigilant-umbrella_prometheus_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/prometheus_data.tar.gz -C /data"
    docker run --rm -v vigilant-umbrella_grafana_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/grafana_data.tar.gz -C /data"
    docker run --rm -v vigilant-umbrella_alertmanager_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/alertmanager_data.tar.gz -C /data"

    echo "Starting services..."
    docker-compose up -d

    echo "Restore completed successfully"
}

function clean_all() {
    echo "WARNING: This will remove all containers and volumes!"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        docker-compose down -v
        echo "All containers and volumes removed"
    else
        echo "Operation cancelled"
    fi
}

function add_website() {
    read -p "Enter website URL to monitor (e.g., https://example.com): " url
    read -p "Enter a label for this website: " label

    echo "Adding $url to monitoring..."

    sed -i "/static_configs:/a\\      - targets:\\n          - $url\\n        labels:\\n          name: '$label'" prometheus/prometheus.yml

    reload_prometheus
    echo "Website added successfully"
}

function reload_prometheus() {
    echo "Reloading Prometheus configuration..."
    docker-compose exec prometheus kill -HUP 1
    echo "Prometheus configuration reloaded"
}

function reload_alertmanager() {
    echo "Reloading Alertmanager configuration..."
    docker-compose exec alertmanager kill -HUP 1
    echo "Alertmanager configuration reloaded"
}

case "$COMMAND" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    logs-tail)
        show_logs_tail
        ;;
    update)
        update_services
        ;;
    backup)
        backup_data
        ;;
    restore)
        restore_data "$@"
        ;;
    clean)
        clean_all
        ;;
    add-website)
        add_website
        ;;
    reload-prometheus)
        reload_prometheus
        ;;
    reload-alertmanager)
        reload_alertmanager
        ;;
    *)
        show_help
        ;;
esac