resource "grafana_rule_group" "infrastructure" {
  name             = "infrastructure"
  folder_uid       = grafana_folder.services.uid
  interval_seconds = 60

  # Authentik - Critical SSO service
  rule {
    name = "AuthentikDown"
    annotations = {
      summary     = "Authentik SSO is down"
      description = "Authentik has been unreachable for 3 minutes. Authentication services are offline!"
    }
    labels = {
      severity = "critical"
      service  = "authentik"
      category = "infrastructure"
    }
    for       = "3m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 180
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"authentik\",namespace=\"security\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Ingress Controllers
  rule {
    name = "IngressControllerDown"
    annotations = {
      summary     = "Ingress controller is down"
      description = "{{ $labels.job }} ingress controller has been down for 5 minutes. External access may be impacted."
    }
    labels = {
      severity = "critical"
      service  = "ingress-nginx"
      category = "infrastructure"
    }
    for       = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=~\"ingress-nginx-.+\",namespace=\"network\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # DNS - Blocky
  rule {
    name = "BlockyDNSDown"
    annotations = {
      summary     = "Blocky DNS resolver is down"
      description = "Blocky has been unreachable for 3 minutes. Internal DNS resolution may be failing."
    }
    labels = {
      severity = "critical"
      service  = "blocky"
      category = "infrastructure"
    }
    for       = "3m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 180
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr  = "up{job=\"resolver-blocky\",namespace=\"network\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Cloudflare Tunnel
  rule {
    name = "CloudflareTunnelDown"
    annotations = {
      summary     = "Cloudflare tunnel is down"
      description = "Cloudflared has been unreachable for 5 minutes. External access via tunnel is offline."
    }
    labels = {
      severity = "warning"
      service  = "cloudflared"
      category = "infrastructure"
    }
    for       = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr  = "up{job=\"cloudflared\",namespace=\"network\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Gatus - Status page
  rule {
    name = "GatusDown"
    annotations = {
      summary     = "Gatus status page is down"
      description = "Gatus has been unreachable for 10 minutes. Status monitoring page is offline."
    }
    labels = {
      severity = "info"
      service  = "gatus"
      category = "infrastructure"
    }
    for       = "10m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"gatus\",namespace=\"observability\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # EMQX - MQTT Broker
  rule {
    name = "EMQXDown"
    annotations = {
      summary     = "EMQX MQTT broker is down"
      description = "EMQX has been unreachable for 5 minutes. IoT/Home automation may be impacted."
    }
    labels = {
      severity = "warning"
      service  = "emqx"
      category = "infrastructure"
    }
    for       = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"emqx-exporter\",namespace=\"observability\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }
}

resource "grafana_rule_group" "response_times" {
  name             = "response-times"
  folder_uid       = grafana_folder.services.uid
  interval_seconds = 60

  # High ingress latency
  rule {
    name = "HighIngressLatency"
    annotations = {
      summary     = "High ingress response times"
      description = "95th percentile response time for {{ $labels.ingress }} is {{ $value }}s (threshold: 5s)"
    }
    labels = {
      severity = "warning"
      category = "performance"
    }
    for       = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "histogram_quantile(0.95, rate(nginx_ingress_controller_request_duration_seconds_bucket[5m])) > 5"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # High error rates
  rule {
    name = "HighErrorRate"
    annotations = {
      summary     = "High HTTP error rate"
      description = "{{ $labels.ingress }} is experiencing {{ $value | humanizePercentage }} 5xx errors"
    }
    labels = {
      severity = "warning"
      category = "performance"
    }
    for       = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "rate(nginx_ingress_controller_requests{status=~\"5..\"}[5m]) / rate(nginx_ingress_controller_requests[5m]) > 0.05"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }
}