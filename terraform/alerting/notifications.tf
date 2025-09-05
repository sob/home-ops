resource "grafana_contact_point" "slack_critical" {
  name = "slack-critical"

  slack {
    url   = module.secrets.items["alertmanager"]["ALERTMANAGER_SLACK_URL"]
    title = "{{ if eq .Status \"resolved\" }}✅ RESOLVED: {{ else }}🚨 {{ end }}{{ .GroupLabels.alertname }}{{ if .GroupLabels.service }} - {{ .GroupLabels.service }}{{ end }}"
    text  = "{{ if or (gt (len .Alerts) 5) (eq .GroupLabels.alertname \"PrometheusDataSourceDown\") }}{{ (index .Alerts 0).Annotations.description }}{{ if gt (len .Alerts) 1 }}\n({{ len .Alerts }} instances){{ end }}{{ else }}{{ range .Alerts }}{{ if .Annotations.description }}• {{ .Annotations.description }}{{ else }}• {{ .Labels.alertname }}: {{ .Annotations.summary }}{{ end }}\n{{ end }}{{ end }}"
    disable_resolve_message = false
  }
}

resource "grafana_contact_point" "slack_warnings" {
  name = "slack-warnings-weekly"

  slack {
    url   = module.secrets.items["alertmanager"]["ALERTMANAGER_SLACK_URL"]
    title = "{{ if eq .Status \"resolved\" }}✅ RESOLVED: Warning - {{ else }}⚠️ Warning - {{ end }}{{ .GroupLabels.alertname }}"
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

  # PRIORITY 1: Prometheus connectivity issues - single alert
  policy {
    matcher {
      label = "alertname"
      match = "="
      value = "PrometheusDataSourceDown"
    }
    group_by        = ["alertname"]
    contact_point   = grafana_contact_point.slack_critical.name
    group_wait      = "10s"  # Alert quickly for infrastructure
    repeat_interval = "1h"   # Remind hourly until fixed
  }

  # PRIORITY 2: All Prometheus-dependent alerts - batch together
  policy {
    matcher {
      label = "depends_on_prometheus"
      match = "="
      value = "true"
    }
    group_by        = ["severity"]  # Group all together by severity only
    contact_point   = grafana_contact_point.slack_critical.name
    group_wait      = "2m"   # Wait to see if it's Prometheus issue
    group_interval  = "10m"  # Less frequent updates
    repeat_interval = "6h"   # Much less frequent reminders
  }

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

  # Node alerts - immediate notification
  policy {
    matcher {
      label = "alertname"
      match = "=~"
      value = "NodeDown|ControlPlaneNodeDown"
    }
    group_by        = ["alertname", "instance"]
    contact_point   = grafana_contact_point.slack_critical.name
    group_wait      = "10s"  # Alert quickly for nodes
    repeat_interval = "2h"   # Remind every 2 hours
  }

  # Critical alerts (non-Prometheus dependent) - individual notifications
  policy {
    matcher {
      label = "severity"
      match = "="
      value = "critical"
    }
    matcher {
      label = "depends_on_prometheus"
      match = "!="
      value = "true"
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
