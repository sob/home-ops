module "secrets" {
  source = "./modules/onepassword"
  vault  = "STONEHEDGES"
  items  = ["grafana-cloud", "alertmanager", "cluster-secrets"]
}

locals {
  # Grafana Cloud credentials from 1Password
  grafana_url  = nonsensitive(module.secrets.items["grafana-cloud"].GRAFANA_URL)
  grafana_auth = module.secrets.items["grafana-cloud"].GRAFANA_CLOUD_TOKEN

  # Public domain, kept out of git
  domain = nonsensitive(module.secrets.items["cluster-secrets"].SECRET_DOMAIN)
}
