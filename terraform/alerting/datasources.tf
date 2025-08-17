# Look up PDC datasource by name
data "grafana_data_source" "prometheus_pdc" {
  name = "prometheus-metal"
}

# Datasource UIDs
locals {
  # Grafana Cloud Prometheus (for forwarded metrics)
  # The default managed datasource uses "grafanacloud-prom" as both name and UID
  prometheus_cloud_uid = "grafanacloud-prom"
  
  # PDC-connected local Prometheus (for infrastructure metrics)
  # Dynamically retrieved: bev3fbylz6dc0f
  prometheus_pdc_uid = data.grafana_data_source.prometheus_pdc.uid
}