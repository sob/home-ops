# Synthetic Monitoring Alerts for K6 Tests

locals {
  # Define all monitored services
  synthetic_services = [
    "jellyfin",
    "jellyseerr", 
    "lidarr",
    "overseerr",
    "plex-external",
    "plex-internal",
    "prowlarr",
    "radarr",
    "readarr",
    "sabnzbd",
    "sonarr",
    "tautulli"
  ]

  # Critical services that should alert immediately
  critical_services = ["plex-external", "overseerr", "jellyseerr"]
  
  # Services with different thresholds
  service_thresholds = {
    default = {
      availability = 0.95  # 95% success rate
      response_time_p95 = 3000  # 3 seconds
      response_time_p99 = 5000  # 5 seconds
    }
    plex-internal = {
      availability = 0.98  # Higher threshold for internal
      response_time_p95 = 2000  # 2 seconds  
      response_time_p99 = 3000  # 3 seconds
    }
  }
}

resource "grafana_rule_group" "synthetic_monitoring" {
  name             = "synthetic-monitoring"
  folder_uid       = grafana_folder.monitoring.uid
  interval_seconds = 60

  # Service Down Alert - Check failure rate
  rule {
    name        = "SyntheticServiceDown"
    annotations = {
      summary     = "Service {{ $labels.service }} is failing tests"
      description = "{{ $labels.service }} has {{ $values.B.Value | printf \"%.1f\" }}% failed checks (threshold < 95% success)"
      runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/SyntheticServiceDown"
    }
    labels = {
      severity = "warning"
      type     = "synthetic"
      depends_on_prometheus = "true"
    }
    for      = "10m"
    condition = "C"
    no_data_state = "NoData"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900  # 15 minutes to ensure we catch tests that run every 10m
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "avg by (service) (k6_checks_rate{service=~\"${join("|", local.synthetic_services)}\"})"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = "-100"  # Math expression
      model          = jsonencode({
        expression = "($A * 100)"
        type = "math"
        refId = "B"
      })
    }

    data {
      ref_id = "C"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = "-100"  # Math expression
      model          = jsonencode({
        expression = "$B < 95"
        type = "math"
        refId = "C"
      })
    }
  }

  # Critical Service Down Alert - Higher severity for critical services
  rule {
    name        = "CriticalServiceDown"
    annotations = {
      summary     = "Critical service {{ $labels.service }} is down"
      description = "{{ $labels.service }} has {{ $values.B.Value | printf \"%.1f\" }}% failed checks"
      runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/CriticalServiceDown"
    }
    labels = {
      severity = "critical"
      type     = "synthetic"
      depends_on_prometheus = "true"
    }
    for      = "5m"  # Alert faster for critical services
    condition = "C"
    no_data_state = "NoData"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "avg by (service) (k6_checks_rate{service=~\"${join("|", local.critical_services)}\"})"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = "-100"
      model          = jsonencode({
        expression = "($A * 100)"
        refId = "B"
      })
    }

    data {
      ref_id = "C"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = "-100"
      model          = jsonencode({
        expression = "$B < 90"  # Lower threshold for critical
        type = "math"
        refId = "C"
      })
    }
  }

  # High Response Time Alert
  rule {
    name        = "ServiceSlowResponse"
    annotations = {
      summary     = "Service {{ $labels.service }} has slow response times"
      description = "{{ $labels.service }} P95 response time is {{ $values.A.Value | printf \"%.0f\" }}ms (threshold > 3000ms)"
      runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/ServiceSlowResponse"
    }
    labels = {
      severity = "warning"
      type     = "synthetic"
      depends_on_prometheus = "true"
    }
    for      = "15m"
    condition = "B"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "histogram_quantile(0.95, sum by (service) (rate(k6_http_req_duration_seconds{service=~\"${join("|", local.synthetic_services)}\"}[15m]))) * 1000"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = "-100"
      model          = jsonencode({
        expression = "$A > 3000"
        type = "math"
        refId = "B"
      })
    }
  }

  # HTTP Request Failures Alert
  rule {
    name        = "ServiceHTTPFailures"
    annotations = {
      summary     = "Service {{ $labels.service }} has HTTP failures"
      description = "{{ $labels.service }} has {{ $values.B.Value | printf \"%.1f\" }}% failed HTTP requests (4xx/5xx)"
      runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/ServiceHTTPFailures"
    }
    labels = {
      severity = "warning"
      type     = "synthetic"
      depends_on_prometheus = "true"
    }
    for      = "10m"
    condition = "C"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "(sum by (service) (rate(k6_http_reqs_total{service=~\"${join("|", local.synthetic_services)}\", status=~\"[45]..\"}[15m])) / sum by (service) (rate(k6_http_reqs_total{service=~\"${join("|", local.synthetic_services)}\"}[15m])))"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = "-100"
      model          = jsonencode({
        expression = "($A * 100)"
        refId = "B"
      })
    }

    data {
      ref_id = "C"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = "-100"
      model          = jsonencode({
        expression = "$B > 10"  # More than 10% failures
        type = "math"
        refId = "C"
      })
    }
  }

  # No Test Data Alert - Detect when tests stop running
  rule {
    name        = "SyntheticTestsMissing"
    annotations = {
      summary     = "Synthetic tests are not running"
      description = "No synthetic test data received in the last 20 minutes"
      runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/SyntheticTestsMissing"
    }
    labels = {
      severity = "warning"
      type     = "synthetic"
      depends_on_prometheus = "true"
    }
    for      = "20m"
    condition = "A"
    no_data_state = "Alerting"  # Alert when no data

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 1200  # 20 minutes
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "sum(increase(k6_iterations_total[20m])) == 0"
        refId = "A"
      })
    }
  }

  # Test Pod Stuck Alert
  rule {
    name        = "SyntheticTestStuck"
    annotations = {
      summary     = "Too many synthetic tests running concurrently"
      description = "{{ $values.A.Value }} tests are running (normal max is 2-3)"
      runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/SyntheticTestStuck"
    }
    labels = {
      severity = "warning"
      type     = "synthetic"
      depends_on_prometheus = "true"
    }
    for      = "5m"
    condition = "B"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "count(count by (job_name) (rate(k6_data_sent_bytes_total[1m]) > 0))"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = "-100"
      model          = jsonencode({
        expression = "$A > 5"  # More than 5 concurrent tests is unusual
        type = "math"
        refId = "B"
      })
    }
  }
}