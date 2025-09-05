module "secrets" {
  source = "./modules/onepassword"
  vault  = "STONEHEDGES"
  items  = ["grafana-cloud", "alertmanager"]
}

locals {
  # Grafana Cloud credentials from 1Password
  grafana_url  = nonsensitive(module.secrets.items["grafana-cloud"].GRAFANA_URL)
  grafana_auth = module.secrets.items["grafana-cloud"].GRAFANA_CLOUD_TOKEN
}