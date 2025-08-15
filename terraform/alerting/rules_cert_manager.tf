resource "grafana_folder" "cert_manager" {
  title = "Cert Manager"
}

resource "grafana_rule_group" "cert_manager" {
  name             = "cert-manager"
  folder_uid       = grafana_folder.cert_manager.uid
  interval_seconds = 60

  rule {
    name        = "CertManagerAbsent"
    annotations = {
      summary = "Cert Manager is absent"
    }
    labels = {
      severity = "critical"
    }
    for      = "10m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "up{job=\"cert-manager\"} == 0"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  rule {
    name        = "CertManagerCertExpirySoon"
    annotations = {
      summary     = "Certificate expiring soon"
      description = "Certificate $${labels.namespace}/$${labels.name} is expiring in $${values.A.Value}"
    }
    labels = {
      severity = "critical"
    }
    for      = "15m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "certmanager_certificate_expiration_timestamp_seconds - time() < 7*24*60*60"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  rule {
    name        = "CertManagerCertNotReady"
    annotations = {
      summary     = "Certificate not ready"
      description = "Certificate $${labels.namespace}/$${labels.name} is not ready"
    }
    labels = {
      severity = "critical"
    }
    for      = "10m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "certmanager_certificate_ready_status{condition=\"False\"} == 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  rule {
    name        = "CertManagerHittingRateLimits"
    annotations = {
      summary     = "Cert Manager hitting rate limits"
      description = "Cert Manager is hitting rate limits"
    }
    labels = {
      severity = "critical"
    }
    for      = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "sum by (host) (rate(certmanager_http_acme_client_request_count{status=\"429\"}[5m])) > 0"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }
}