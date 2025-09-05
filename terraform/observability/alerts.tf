# Synthetic Monitoring Alerts - One per service for proper labeling

# Get the monitoring folder from Grafana Cloud
data "grafana_folder" "monitoring_alerts" {
  title = "Monitoring & Observability"
}

# Create alert rule group for synthetic monitoring
resource "grafana_rule_group" "synthetic_monitoring" {
  name             = "synthetic-monitoring"
  folder_uid       = data.grafana_folder.monitoring_alerts.uid
  interval_seconds = 60

  # Alert 1: Synthetic tests failing (success rate < 95%)
  dynamic "rule" {
    for_each = local.k6_test_configs
    content {
      name = "SyntheticTestsFailing-${rule.key}"
      
      annotations = {
        summary     = "K6 synthetic tests failing for ${rule.key}"
        description = "${rule.key} synthetic tests alert triggered"
        runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/SyntheticTestsFailing"
        service     = rule.key
      }
      
      labels = {
        severity = "critical"
        type     = "synthetic"
        service  = rule.key
      }
      
      for               = "5m"
      condition         = "A"
      no_data_state     = "OK"
      exec_err_state    = "Alerting"
      
      # Query A: Success rate check
      data {
        ref_id = "A"
        
        relative_time_range {
          from = 600
          to   = 0
        }
        
        datasource_uid = local.prometheus_datasource_uid
        model = jsonencode({
          expr  = "(avg(avg_over_time(k6_checks_rate{service=\"${rule.key}\"}[10m])) * 100) < 95"
          refId = "A"
        })
      }
    }
  }

  # Alert 2: No synthetic test data (tests not running)
  dynamic "rule" {
    for_each = local.k6_test_configs
    content {
      name = "SyntheticTestsNotRunning-${rule.key}"
      
      annotations = {
        summary     = "K6 synthetic tests not running for ${rule.key}"
        description = "${rule.key} synthetic tests have not produced metrics in the last 10 minutes"
        runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/SyntheticTestsNotRunning"
        service     = rule.key
      }
      
      labels = {
        severity = "warning"
        type     = "synthetic"
        service  = rule.key
      }
      
      for               = "10m"
      condition         = "A"
      no_data_state     = "OK"  # This is handled by the absent() query
      exec_err_state    = "Alerting"
      
      # Query A: Alert when no metrics exist
      data {
        ref_id = "A"
        
        relative_time_range {
          from = 600
          to   = 0
        }
        
        datasource_uid = local.prometheus_datasource_uid
        model = jsonencode({
          expr  = "absent(k6_checks_rate{service=\"${rule.key}\"})"
          refId = "A"
        })
      }
    }
  }

  # Additional rule for high response times
  dynamic "rule" {
    for_each = local.k6_test_configs
    content {
      name = "SyntheticSlowResponse-${rule.key}"
      
      annotations = {
        summary     = "Service ${rule.key} has slow response times"
        description = "${rule.key} P95 response time is {{ $value | printf \"%.0f\" }}ms (threshold > 3000ms)"
        runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/ServiceSlowResponse"
        service     = rule.key
      }
      
      labels = {
        severity = "warning"
        type     = "synthetic"
        service  = rule.key
      }
      
      for               = "10m"
      condition         = "A"
      no_data_state     = "OK"  # Don't alert on missing response time metrics
      exec_err_state    = "OK"
      
      # Query A: Get P95 response time
      data {
        ref_id = "A"
        
        relative_time_range {
          from = 600
          to   = 0
        }
        
        datasource_uid = local.prometheus_datasource_uid
        model = jsonencode({
          expr  = "histogram_quantile(0.95, sum by (le) (rate(k6_http_req_duration_seconds_bucket{service=\"${rule.key}\"}[10m]))) * 1000"
          refId = "A"
        })
      }
      
      # Query B: Alert if P95 > 3000ms
      data {
        ref_id = "B"
        
        relative_time_range {
          from = 600
          to   = 0
        }
        
        datasource_uid = "-100"  # Math expression datasource
        model = jsonencode({
          expression = "$A > 3000"
          type       = "math"
          refId      = "B"
        })
      }
    }
  }
}

# Note: K6 Operator infrastructure monitoring moved to PrometheusRules
# This section now focuses on service-level synthetic monitoring