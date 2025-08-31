# Grafana Cloud Dashboard Management

# Import k6 dashboard from Grafana Labs
data "http" "k6_dashboard" {
  url = "https://grafana.com/api/dashboards/19665/revisions/latest/download"
}

data "grafana_folder" "monitoring" {
  title = "Monitoring & Observability"
}

# Official k6 Prometheus Dashboard
resource "grafana_dashboard" "k6_prometheus" {
  folder      = data.grafana_folder.monitoring.id
  config_json = data.http.k6_dashboard.response_body
  overwrite   = true
}

# Synthetic Monitoring Dashboard
resource "grafana_dashboard" "synthetic_monitoring" {
  folder = data.grafana_folder.monitoring.id
  config_json = replace(
    file("${path.module}/dashboards/media-services.json"),
    "PROMETHEUS_DATASOURCE_UID_PLACEHOLDER",
    local.prometheus_datasource_uid
  )
  overwrite = true
}