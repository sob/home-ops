# Fetch Grafana Cloud credentials from 1Password
module "grafana_secrets" {
  source = "./modules/onepassword"
  vault  = var.onepassword_vault
  items  = ["grafana-cloud"]
}

locals {
  # Pull Grafana credentials from 1Password grafana-cloud item
  # Required fields in 1Password item:
  # - GRAFANA_URL: Your Grafana Cloud URL (e.g., https://your-stack.grafana.net)
  # - GRAFANA_CLOUD_TOKEN: API key with Editor permissions
  # - GRAFANA_CLOUD_PDC_DATASOURCE_ID: Prometheus datasource UID
  
  grafana_url  = nonsensitive(module.grafana_secrets.items["grafana-cloud"].GRAFANA_URL)
  grafana_auth = module.grafana_secrets.items["grafana-cloud"].GRAFANA_CLOUD_TOKEN
  
  # Get the Prometheus datasource UID from 1Password
  prometheus_datasource_uid = try(
    nonsensitive(module.grafana_secrets.items["grafana-cloud"].GRAFANA_CLOUD_PDC_DATASOURCE_ID),
    "prometheus-pdc" # Default fallback
  )
}