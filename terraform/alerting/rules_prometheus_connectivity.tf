# Folder defined in folders.tf

resource "grafana_rule_group" "prometheus_connectivity" {
  name             = "prometheus-connectivity"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 30  # Check frequently for quick detection

  rule {
    name = "PrometheusDataSourceDown"
    annotations = {
      summary     = "Prometheus datasource is unreachable"
      description = "Cannot query Prometheus via PDC connection. All metric-based alerts are affected."
      runbook_url = "https://docs.56kbps.io/runbooks/prometheus-unreachable"
    }
    labels = {
      severity     = "critical"
      component    = "prometheus"
      alertname    = "PrometheusDataSourceDown"
      datasource   = "prometheus-metal"
      inhibit_alerts = "prometheus_dependent"  # Tag to identify this inhibits other alerts
    }
    for           = "1m"  # Quick detection
    condition     = "A"
    no_data_state = "Alerting"  # Alert when no data (means Prometheus is down)
    exec_err_state = "Alerting"  # Alert on query errors too

    # Test datasource connectivity with a simple query
    data {
      ref_id = "A"
      
      relative_time_range {
        from = 60
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      
      # Simple query that should always return exactly 1 if Prometheus is up
      model = jsonencode({
        expr    = "vector(1)"
        refId   = "A"
        instant = true
      })
    }
  }
}

