provider "grafana" {
  url  = module.secrets.items["grafana-cloud"]["GRAFANA_URL"]
  auth = module.secrets.items["grafana-cloud"]["GRAFANA_CLOUD_TOKEN"]
}