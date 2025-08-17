resource "grafana_contact_point" "slack_critical" {
  name = "slack-critical"

  slack {
    url   = module.secrets.items["alertmanager"]["ALERTMANAGER_SLACK_URL"]
    title = "🚨 {{ .GroupLabels.alertname }}{{ if .GroupLabels.service }} - {{ .GroupLabels.service }}{{ end }}"
    text  = "{{ range .Alerts }}{{ if .Annotations.description }}• {{ .Annotations.description }}{{ else }}• {{ .Labels.alertname }}: {{ .Annotations.summary }}{{ end }}\n{{ end }}"
    disable_resolve_message = false
  }
}

resource "grafana_contact_point" "slack_warnings" {
  name = "slack-warnings-weekly"

  slack {
    url   = module.secrets.items["alertmanager"]["ALERTMANAGER_SLACK_URL"]
    title = "⚠️ Warning - {{ .GroupLabels.alertname }}"
    text  = "{{ range .Alerts }}{{ if .Annotations.description }}• {{ .Annotations.description }}{{ else }}• {{ .Labels.service }}: {{ .Annotations.summary }}{{ end }}\n{{ end }}"
    disable_resolve_message = true
  }
}

resource "grafana_notification_policy" "main" {
  group_by        = ["alertname", "service"]  # Group by both alert name and service
  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"

  contact_point = grafana_contact_point.slack_critical.name

  # DatasourceNoData errors - group them together
  policy {
    matcher {
      label = "alertname"
      match = "="
      value = "DatasourceNoData"
    }
    group_by        = ["alertname"]  # Group all datasource errors together
    contact_point   = grafana_contact_point.slack_critical.name
    repeat_interval = "12h"  # Less frequent for system errors
    mute_timings    = []
  }

  # Critical alerts - individual notifications
  policy {
    matcher {
      label = "severity"
      match = "="
      value = "critical"
    }
    group_by        = ["alertname", "instance", "service"]  # Group by alert, instance, and service
    contact_point   = grafana_contact_point.slack_critical.name
    repeat_interval = "4h"
  }

  # Warning alerts - weekly summary
  policy {
    matcher {
      label = "severity"
      match = "="
      value = "warning"
    }
    group_by        = ["..."]
    contact_point   = grafana_contact_point.slack_warnings.name
    repeat_interval = "1w"  # Weekly
  }
}
