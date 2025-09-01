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

  # Create individual alert rules for each service
  dynamic "rule" {
    for_each = local.k6_test_configs
    content {
      name = "SyntheticServiceDown-${rule.key}"
      
      annotations = {
        summary     = "Service ${rule.key} is failing synthetic tests"
        description = "${rule.key} has ${contains(["plex-external", "overseerr", "jellyseerr"], rule.key) ? "critical" : "warning"} failures - success rate: {{ $values.A.Value | printf \"%.0f\" }}%"
        runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/SyntheticServiceDown"
        service     = rule.key
      }
      
      labels = {
        severity = contains(["plex-external", "overseerr", "jellyseerr"], rule.key) ? "critical" : "warning"
        type     = "synthetic"
        service  = rule.key
      }
      
      for               = contains(["plex-external", "overseerr", "jellyseerr"], rule.key) ? "5m" : "6m"
      condition         = "B"
      no_data_state     = contains(["plex-external", "overseerr", "jellyseerr"], rule.key) ? "Alerting" : "OK"  # Only critical services alert on no data
      exec_err_state    = "Alerting"
      
      # Query A: Get success rate or 0 if no metrics
      data {
        ref_id = "A"
        
        relative_time_range {
          from = 600  # 10 minutes to capture 2 test runs
          to   = 0
        }
        
        datasource_uid = local.prometheus_datasource_uid
        model = jsonencode({
          expr  = "(avg(avg_over_time(k6_checks_rate{service=\"${rule.key}\"}[10m])) * 100) or on() vector(0)"
          refId = "A"
        })
      }
      
      # Query B: Alert condition - success rate < 95% or no data
      data {
        ref_id = "B"
        
        relative_time_range {
          from = 600
          to   = 0
        }
        
        datasource_uid = local.prometheus_datasource_uid
        model = jsonencode({
          expr  = "(absent_over_time(k6_checks_rate{service=\"${rule.key}\"}[10m]) == 1) or ((avg(avg_over_time(k6_checks_rate{service=\"${rule.key}\"}[10m])) * 100) < 95)"
          refId = "B"
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
        description = "${rule.key} P95 response time is {{ $values.A.Value | printf \"%.0f\" }}ms (threshold > 3000ms)"
        runbook_url = "https://github.com/seobrien/home-ops/wiki/Alerts/ServiceSlowResponse"
        service     = rule.key
      }
      
      labels = {
        severity = "warning"
        type     = "synthetic"
        service  = rule.key
      }
      
      for               = "10m"
      condition         = "B"
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