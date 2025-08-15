resource "grafana_contact_point" "slack_critical" {
  name = "slack-critical"

  slack {
    url   = module.secrets.items["alertmanager"]["ALERTMANAGER_SLACK_URL"]
    title = "🚨 [CRITICAL] {{ .GroupLabels.alertname }}"
    text  = "{{ range .Alerts }}*{{ .Annotations.summary }}*\n{{ .Annotations.description }}{{ end }}"
    disable_resolve_message = false
  }
}

resource "grafana_contact_point" "slack_warnings" {
  name = "slack-warnings-weekly"

  slack {
    url   = module.secrets.items["alertmanager"]["ALERTMANAGER_SLACK_URL"]
    title = "⚠️ Weekly Warning Summary"
    text  = "{{ len .Alerts }} warning alerts:\n{{ range .Alerts }}- {{ .Labels.alertname }}: {{ .Annotations.summary }}\n{{ end }}"
    disable_resolve_message = true
  }
}

resource "grafana_notification_policy" "main" {
  group_by        = ["alertname", "instance"]
  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"

  contact_point = grafana_contact_point.slack_critical.name

  # Critical alerts - immediate notification
  policy {
    matcher {
      label = "severity"
      match = "="
      value = "critical"
    }
    group_by        = ["alertname", "instance", "service"]
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
