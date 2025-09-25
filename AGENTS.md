# Repository Guidelines
The vigilant-umbrella stack packages Prometheus, Grafana, and alert routing for joint observability. Use this guide to keep deployments predictable.

## Project Structure & Module Organization
- `docker-compose.yml` orchestrates local services; config lives under `prometheus/`, `alertmanager/`, `grafana/`, `blackbox/`, and `nginx/`.
- `terraform/` provisions DigitalOcean droplets, DNS, and firewall rules; `user-data.tpl` holds cloud-init bootstrap logic.
- Shell utilities (`manage.sh`, `create-droplet.sh`, `terraform-deploy.sh`, `check-services.sh`) live in the root; reference docs are in `MIGRATION-GUIDE.md`, `TERRAFORM.md`, and `DEPLOYMENT.md`.
- Sample inputs sit in `.env.example` and `sites.txt.example`; adjust copies rather than editing originals.

## Build, Test, and Development Commands
- `docker-compose up -d` launches the monitoring stack locally; follow with `./manage.sh status` to confirm container health.
- `./manage.sh logs` or `logs-tail` aggregates service logs; `./manage.sh update` pulls fresh images and restarts safely.
- `cd terraform && terraform fmt && terraform validate` keeps HCL formatted and schema-checked before planning changes.
- `terraform plan` (or `./terraform-deploy.sh`) previews infrastructure drift; only run `terraform apply` after peer review.

## Coding Style & Naming Conventions
- Match indentation conventions: two-space YAML, four-space Bash blocks, and tab-free Terraform files.
- Run `terraform fmt` on every change; keep variables `snake_case` and directories kebab-case (e.g., `alertmanager`).
- Bash functions stay lower_snake_case with `set -e` at the top; prefer descriptive script names like `fix-droplet-services.sh`.
- Secrets belong in environment overrides or Terraform variables; never commit live credentials.

## Testing Guidelines
- `docker-compose config -q` lint checks compose updates; `docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml` validates rule syntax.
- Always capture `terraform plan` output and share the diff in PR discussions; run `terraform validate` locally before pushing.
- After infra changes, run `./manage.sh restart` on a staging host and confirm Grafana dashboards and Alertmanager routes render as expected.

## Commit & Pull Request Guidelines
- Follow the imperative tone in history (`Add migration helpers`, `Fix: tighten firewall rules`); keep subjects under ~72 characters with optional `Fix:` prefixes for patches.
- PRs should summarize impact, list affected services, and paste relevant command output (plan, config checks, logs).
- Wait for the Terraform GitHub Action to pass `fmt`, `init`, `validate`, and plan steps; respond to comments before requesting approval.

## Security & Configuration Tips
- Use `.env` overrides for `GRAFANA_USER`, `GRAFANA_PASSWORD`, SMTP credentials, and web basic auth; avoid updating tracked files directly.
- Restrict Grafana and Prometheus ingress via `nginx/nginx.conf` and Terraform `monitoring_allowed_ips`; review firewall rules when adding dashboards.
- Rotate archives created with `./manage.sh backup` and test restores on disposable droplets to ensure recoverability.
