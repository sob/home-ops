output "prometheus_cloud_uid" {
  value = local.prometheus_cloud_uid
  description = "UID of the Grafana Cloud Prometheus datasource"
}

output "prometheus_pdc_uid" {
  value = data.grafana_data_source.prometheus_pdc.uid
  description = "UID of the PDC-connected Prometheus datasource"
}

output "prometheus_pdc_info" {
  value = {
    name = data.grafana_data_source.prometheus_pdc.name
    uid  = data.grafana_data_source.prometheus_pdc.uid
    type = data.grafana_data_source.prometheus_pdc.type
    url  = data.grafana_data_source.prometheus_pdc.url
  }
  description = "Full info for PDC Prometheus datasource"
}

output "grafana_url" {
  value = local.grafana_url
  description = "Grafana Cloud URL"
}

output "grafana_token" {
  value = local.grafana_auth
  sensitive = true
  description = "Grafana Cloud API token"
}

output "slack_webhook_url" {
  value = module.secrets.items["alertmanager"]["ALERTMANAGER_SLACK_URL"]
  sensitive = true
  description = "Slack webhook URL for testing notifications"
}