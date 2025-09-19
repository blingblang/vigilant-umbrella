variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "observability"
}

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
  default     = "production"
}

# Droplet Configuration
variable "droplet_name" {
  description = "Name of the DigitalOcean droplet"
  type        = string
  default     = "observability-stack"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = "Droplet size"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "droplet_image" {
  description = "Droplet image"
  type        = string
  default     = "ubuntu-22-04-x64"
}

# SSH Configuration
variable "ssh_public_key_path" {
  description = "Path to SSH public key file (leave empty to use existing keys)"
  type        = string
  default     = ""
}

variable "existing_ssh_key_ids" {
  description = "List of existing SSH key IDs in DigitalOcean"
  type        = list(string)
  default     = []
}

variable "ssh_allowed_ips" {
  description = "IP addresses allowed to SSH (use [\"0.0.0.0/0\"] for all)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Monitoring Access
variable "monitoring_allowed_ips" {
  description = "IP addresses allowed to access monitoring services"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "expose_prometheus" {
  description = "Expose Prometheus to external access"
  type        = bool
  default     = false
}

variable "expose_alertmanager" {
  description = "Expose Alertmanager to external access"
  type        = bool
  default     = false
}

# Grafana Configuration
variable "grafana_password" {
  description = "Grafana admin password (auto-generated if not provided)"
  type        = string
  sensitive   = true
  default     = ""
}

# Alert Configuration
variable "alert_email" {
  description = "Email address for alerts"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "smtp_host" {
  description = "SMTP server host"
  type        = string
  default     = "smtp.gmail.com:587"
}

variable "smtp_from" {
  description = "From email address for alerts"
  type        = string
  default     = "alertmanager@example.com"
}

variable "smtp_username" {
  description = "SMTP username"
  type        = string
  default     = ""
}

variable "smtp_password" {
  description = "SMTP password"
  type        = string
  default     = ""
  sensitive   = true
}

# Website Monitoring
variable "websites_to_monitor" {
  description = "List of websites to monitor"
  type = list(object({
    url   = string
    label = string
  }))
  default = [
    {
      url   = "https://example.com"
      label = "Example Website"
    }
  ]
}

# Networking
variable "use_reserved_ip" {
  description = "Use a reserved IP address"
  type        = bool
  default     = true
}

# DNS Configuration
variable "manage_dns" {
  description = "Manage DNS records in DigitalOcean"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for the observability stack"
  type        = string
  default     = ""
}

variable "subdomain" {
  description = "Subdomain for the observability stack"
  type        = string
  default     = "monitoring"
}

# SSL Configuration
variable "enable_ssl" {
  description = "Enable SSL with Let's Encrypt"
  type        = bool
  default     = false
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificates"
  type        = string
  default     = ""
}

# Backup Configuration
variable "enable_backup_bucket" {
  description = "Create DigitalOcean Spaces bucket for backups"
  type        = bool
  default     = false
}

variable "spaces_region" {
  description = "Region for DigitalOcean Spaces bucket"
  type        = string
  default     = "nyc3"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

# Project Management
variable "create_project" {
  description = "Create a DigitalOcean project for resources"
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = list(string)
  default     = []
}