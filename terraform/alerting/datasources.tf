# Datasource UIDs from 1Password
locals {
  # Grafana Cloud Prometheus (for forwarded metrics)
  prometheus_cloud_uid = module.secrets.items["grafana-cloud"]["GRAFANA_CLOUD_DATASOURCE_ID"]
  
  # PDC-connected local Prometheus (for infrastructure metrics)
  prometheus_pdc_uid = module.secrets.items["grafana-cloud"]["GRAFANA_CLOUD_PDC_DATASOURCE_ID"]
}