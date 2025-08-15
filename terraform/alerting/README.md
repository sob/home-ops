# Grafana Cloud Alerting

This Terraform configuration manages alert rules and notification channels for Grafana Cloud.

## Setup

1. Create required 1Password items in your STONEHEDGES vault:
   
   **grafana-cloud** item with fields:
   - `GRAFANA_CLOUD_TOKEN` - Access token with alerts/notifications scopes
   - `GRAFANA_URL` - Your Grafana Cloud URL (e.g., https://stonehedges.grafana.net)
   
   **alertmanager** item with fields:
   - `ALERTMANAGER_SLACK_URL` - Slack webhook URL

2. Create a Grafana Cloud Service Account:
   - Go to your Grafana instance (e.g., https://stonehedges.grafana.net)
   - Navigate to Administration → Service accounts
   - Click "Add service account"
   - Name it "terraform-alerting"
   - Assign the "Editor" role (or "Admin" if you need full control)
   - Click "Create"
   - On the service account page, click "Add service account token"
   - Name the token and generate it
   - Copy the token (starts with `glsa_`)
   
   Note: For Grafana Cloud, you can also create a Cloud Access Policy token from grafana.com,
   but a service account token from your Grafana instance works well for Terraform

3. Create `terraform.tfvars` with your values:
   ```hcl
   onepassword_account = "my.1password.com"
   prometheus_datasource_uid = "grafanacloud-prom"  # Find in Grafana Data Sources
   ```

4. Initialize and apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Alert Structure

Alerts are organized by domain:
- **Kubernetes** - OOM kills, Docker Hub rate limits
- **Cert Manager** - Certificate expiry, rate limits
- **Storage** - SMART monitoring, VolSync backups
- **Flux** - GitOps reconciliation failures

## Adding New Alerts

1. Create a new rule group in the appropriate file
2. Use the Grafana UI to build and test queries
3. Copy the PromQL expression to Terraform
4. Apply changes with `terraform apply`

## Migrating from PrometheusRules

The alert rules in this configuration were migrated from Kubernetes PrometheusRule CRDs. The queries remain the same, but are now evaluated by Grafana Cloud instead of local Prometheus.