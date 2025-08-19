resource "grafana_folder" "flux" {
  title = "Flux"
}

resource "grafana_rule_group" "flux" {
  name             = "flux"
  folder_uid       = grafana_folder.flux.uid
  interval_seconds = 60

  rule {
    name        = "FluxInstanceAbsent"
    annotations = {
      summary = "Flux instance is absent"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "10m"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "min(up{job=~\"flux.*\"}) < 1"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "FluxInstanceNotReady"
    annotations = {
      summary     = "Flux instance not ready"
      description = "Flux instance $${labels.instance} is not ready"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "10m"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "min by (instance) (fluxcd_controller_ready) != 1"
        refId = "A"
        instant = true      })
    }
  }
}

resource "grafana_rule_group" "external_secrets" {
  name             = "external-secrets"
  folder_uid       = grafana_folder.flux.uid
  interval_seconds = 60

  rule {
    name        = "SecretSyncError"
    annotations = {
      summary     = "External Secret sync error"
      description = "External secret $${labels.name} in namespace $${labels.namespace} has sync errors"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "5m"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "increase(sync_calls{status=\"error\"}[5m]) by (name, namespace) > 0"
        refId = "A"
        instant = true      })
    }
  }
}