output "droplet_ip" {
  description = "Public IP address of the droplet"
  value       = var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address
}

output "droplet_ipv6" {
  description = "IPv6 address of the droplet"
  value       = digitalocean_droplet.observability.ipv6_address
}

output "grafana_url" {
  description = "Grafana URL"
  value       = var.enable_ssl && var.manage_dns ? "https://${var.subdomain}.${var.domain_name}:3000" : "http://${var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address}:9090"
}

output "alertmanager_url" {
  description = "Alertmanager URL"
  value       = "http://${var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address}:9093"
}

output "grafana_password" {
  description = "Grafana admin password"
  value       = local.grafana_password
  sensitive   = true
}

output "ssh_command" {
  description = "SSH command to connect to the droplet"
  value       = "ssh root@${var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address}"
}

output "droplet_id" {
  description = "ID of the created droplet"
  value       = digitalocean_droplet.observability.id
}

output "firewall_id" {
  description = "ID of the created firewall"
  value       = digitalocean_firewall.observability.id
}

output "backup_bucket_endpoint" {
  description = "Endpoint for backup bucket (if enabled)"
  value       = var.enable_backup_bucket ? digitalocean_spaces_bucket.backups[0].bucket_domain_name : null
}

output "project_id" {
  description = "ID of the created project (if enabled)"
  value       = var.create_project ? digitalocean_project.observability[0].id : null
}

output "monitoring_instructions" {
  description = "Instructions for accessing the monitoring stack"
  value = <<EOF
Observability Stack Deployed Successfully!

Access your services:
  Grafana:      ${var.enable_ssl && var.manage_dns ? "https://${var.subdomain}.${var.domain_name}:3000" : "http://${var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address}:3000"}
  Prometheus:   http://${var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address}:9090
  Alertmanager: http://${var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address}:9093

Credentials:
  Username: admin
  Password: Run 'terraform output -raw grafana_password' to see the password

SSH Access:
  ssh root@${var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address}

Remote Management:
  ./remote-manage.sh ${var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address}
EOF
}