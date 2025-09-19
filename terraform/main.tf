terraform {
  required_version = ">= 1.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "digitalocean" {
  # Token is automatically read from DIGITALOCEAN_TOKEN environment variable
  # or can be explicitly set via var.do_token
}

# Generate random password if not provided
resource "random_password" "grafana_password" {
  length  = 16
  special = true
  override_special = "!@#$%^&*"
}

# Create SSH key if provided
resource "digitalocean_ssh_key" "observability" {
  count      = var.ssh_public_key_path != "" ? 1 : 0
  name       = "${var.project_name}-ssh-key"
  public_key = file(var.ssh_public_key_path)
}

# Reserved IP for the droplet
resource "digitalocean_reserved_ip" "observability" {
  count  = var.use_reserved_ip ? 1 : 0
  region = var.region
}

# Firewall configuration
resource "digitalocean_firewall" "observability" {
  name = "${var.project_name}-firewall"

  droplet_ids = [digitalocean_droplet.observability.id]

  # SSH access
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_allowed_ips
  }

  # Grafana
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3000"
    source_addresses = var.monitoring_allowed_ips
  }

  # Prometheus (optional external access)
  dynamic "inbound_rule" {
    for_each = var.expose_prometheus ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "9090"
      source_addresses = var.monitoring_allowed_ips
    }
  }

  # Alertmanager (optional external access)
  dynamic "inbound_rule" {
    for_each = var.expose_alertmanager ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "9093"
      source_addresses = var.monitoring_allowed_ips
    }
  }

  # HTTP/HTTPS for nginx reverse proxy
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Create user data script for cloud-init
locals {
  grafana_password = var.grafana_password != "" ? var.grafana_password : random_password.grafana_password.result

  user_data = templatefile("${path.module}/user-data.tpl", {
    grafana_password    = local.grafana_password
    alert_email        = var.alert_email
    slack_webhook_url  = var.slack_webhook_url
    docker_compose_yml = file("${path.root}/../docker-compose.yml")
    prometheus_yml     = file("${path.root}/../prometheus/prometheus.yml")
    alert_rules_yml    = file("${path.root}/../prometheus/alert_rules.yml")
    alertmanager_yml   = templatefile("${path.root}/../alertmanager/alertmanager.yml", {
      alert_email       = var.alert_email
      slack_webhook_url = var.slack_webhook_url
      smtp_host        = var.smtp_host
      smtp_from        = var.smtp_from
      smtp_username    = var.smtp_username
      smtp_password    = var.smtp_password
    })
    blackbox_yml       = file("${path.root}/../blackbox/blackbox.yml")
    nginx_conf         = file("${path.root}/../nginx/nginx.conf")
    grafana_datasource = file("${path.root}/../grafana/provisioning/datasources/prometheus.yml")
    grafana_dashboards = file("${path.root}/../grafana/provisioning/dashboards/dashboards.yml")
    grafana_dashboard_json = file("${path.root}/../grafana/dashboards/system-overview.json")
    websites_to_monitor = var.websites_to_monitor
    enable_ssl         = var.enable_ssl
    domain_name        = var.domain_name
    subdomain          = var.subdomain
    letsencrypt_email  = var.letsencrypt_email
  })
}

# Create the droplet
resource "digitalocean_droplet" "observability" {
  name     = var.droplet_name
  region   = var.region
  size     = var.droplet_size
  image    = var.droplet_image
  monitoring = true
  ipv6     = true

  ssh_keys = var.ssh_public_key_path != "" ? [digitalocean_ssh_key.observability[0].fingerprint] : var.existing_ssh_key_ids

  user_data = local.user_data

  tags = concat([var.project_name, "observability", "monitoring"], var.additional_tags)
}

# Assign reserved IP if created
resource "digitalocean_reserved_ip_assignment" "observability" {
  count      = var.use_reserved_ip ? 1 : 0
  ip_address = digitalocean_reserved_ip.observability[0].ip_address
  droplet_id = digitalocean_droplet.observability.id
}

# Create DNS records if domain is managed in DigitalOcean
resource "digitalocean_record" "observability_a" {
  count  = var.manage_dns ? 1 : 0
  domain = var.domain_name
  type   = "A"
  name   = var.subdomain
  value  = var.use_reserved_ip ? digitalocean_reserved_ip.observability[0].ip_address : digitalocean_droplet.observability.ipv4_address
  ttl    = 300
}

resource "digitalocean_record" "observability_aaaa" {
  count  = var.manage_dns ? 1 : 0
  domain = var.domain_name
  type   = "AAAA"
  name   = var.subdomain
  value  = digitalocean_droplet.observability.ipv6_address
  ttl    = 300
}

# Create DigitalOcean Spaces for backups (optional)
resource "digitalocean_spaces_bucket" "backups" {
  count  = var.enable_backup_bucket ? 1 : 0
  name   = "${var.project_name}-observability-backups"
  region = var.spaces_region
  acl    = "private"

  lifecycle_rule {
    enabled = true
    expiration {
      days = var.backup_retention_days
    }
  }
}

# Create project and assign resources
resource "digitalocean_project" "observability" {
  count       = var.create_project ? 1 : 0
  name        = "${var.project_name}-observability"
  description = "Observability stack for monitoring websites and infrastructure"
  purpose     = "Operational / Developer tooling"
  environment = var.environment

  resources = concat(
    [digitalocean_droplet.observability.urn],
    var.use_reserved_ip ? [digitalocean_reserved_ip.observability[0].urn] : [],
    var.enable_backup_bucket ? [digitalocean_spaces_bucket.backups[0].urn] : []
  )
}