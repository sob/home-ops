# Consolidated Alert Rules - Organized by Domain

# =============================================================================
# INFRASTRUCTURE - Core cluster and node health
# =============================================================================
resource "grafana_folder" "infrastructure" {
  title = "Infrastructure"
}

resource "grafana_rule_group" "node_availability" {
  name             = "node-availability"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 60

  # Alert when any node is down (using blackbox ICMP probes)
  rule {
    name        = "NodeDown"
    annotations = {
      summary     = "Kubernetes node is down"
      description = "Node $${labels.instance} has been unreachable for 5 minutes"
    }
    labels = {
      severity = "critical"
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
      
      datasource_uid = local.prometheus_cloud_uid
      model          = jsonencode({
        expr = "probe_success{probe_type=\"node_icmp\", instance=~\"10.1.100.10[1-7]\"} == 0"
        refId = "A"
        instant = true
      })
    }
  }

  # Alert when control plane node is down (using blackbox ICMP probes)
  rule {
    name        = "ControlPlaneNodeDown"
    annotations = {
      summary     = "Control plane node is down"
      description = "Control plane node $${labels.instance} has been unreachable for 2 minutes"
    }
    labels = {
      severity = "critical"
    }
    for      = "2m"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 120
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model          = jsonencode({
        expr = "probe_success{probe_type=\"node_icmp\", instance=~\"10.1.100.10[1-3]\"} == 0"
        refId = "A"
        instant = true
      })
    }
  }
}

# Move prometheus connectivity alerts here since they're infrastructure
resource "grafana_rule_group" "prometheus_connectivity" {
  name             = "prometheus-connectivity"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 60

  rule {
    name = "PrometheusDataSourceDown"
    annotations = {
      summary     = "Prometheus data source is unreachable"
      description = "Cannot connect to on-premises Prometheus instance"
    }
    labels = {
      severity                 = "critical"
      depends_on_prometheus    = "true"
    }
    for           = "2m"
    condition     = "A"
    no_data_state = "Alerting"
    exec_err_state = "Alerting"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "up{job=\"prometheus\"}"
        refId   = "A"
        instant = false
      })
    }
  }
}

# Power/UPS alerts are also infrastructure
resource "grafana_rule_group" "power" {
  name             = "power"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 60

  rule {
    name = "UPSOnBattery"
    annotations = {
      summary     = "UPS is running on battery power"
      description = "UPS $${labels.ups_name} has been on battery for 2 minutes"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    for           = "2m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "nut_ups_status{flag=\"OB\"} == 1"
        refId   = "A"
        instant = true
      })
    }
  }

  rule {
    name = "UPSLowBattery"
    annotations = {
      summary     = "UPS battery is critically low"
      description = "UPS $${labels.ups_name} battery is below 20%"
    }
    labels = {
      severity                 = "critical"
      depends_on_prometheus    = "true"
    }
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 60
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "nut_battery_charge < 20"
        refId   = "A"
        instant = true
      })
    }
  }

  rule {
    name = "PDUOutletDown"
    annotations = {
      summary     = "PDU outlet has no power"
      description = "PDU outlet $${labels.outlet} is not providing power"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    for           = "5m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "snmp_pdu_outlet_power == 0"
        refId   = "A"
        instant = true
      })
    }
  }
}

# =============================================================================
# STORAGE - Disks, Ceph, Volsync backups
# =============================================================================
resource "grafana_folder" "storage" {
  title = "Storage"
}

resource "grafana_rule_group" "smartctl" {
  name             = "smartctl"
  folder_uid       = grafana_folder.storage.uid
  interval_seconds = 60

  rule {
    name = "DiskFailurePredicted"
    annotations = {
      summary     = "Disk failure predicted by SMART"
      description = "Disk $${labels.device} on $${labels.instance} is predicted to fail"
    }
    labels = {
      severity                 = "critical"
      depends_on_prometheus    = "true"
    }
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "smartctl_device_smart_status == 0"
        refId   = "A"
        instant = true
      })
    }
  }

  rule {
    name = "DiskHighTemperature"
    annotations = {
      summary     = "Disk temperature is too high"
      description = "Disk $${labels.device} on $${labels.instance} is at $${values.A}°C"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    for           = "10m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "smartctl_device_temperature > 55"
        refId   = "A"
        instant = true
      })
    }
  }
}

resource "grafana_rule_group" "ceph" {
  name             = "ceph"
  folder_uid       = grafana_folder.storage.uid
  interval_seconds = 60

  rule {
    name = "CephHealthWarning"
    annotations = {
      summary     = "Ceph cluster health is degraded"
      description = "Ceph cluster is in WARNING state"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    for           = "5m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "ceph_health_status == 1"
        refId   = "A"
        instant = true
      })
    }
  }

  rule {
    name = "CephOSDDown"
    annotations = {
      summary     = "Ceph OSD is down"
      description = "$${values.A} OSD(s) are down"
    }
    labels = {
      severity                 = "critical"
      depends_on_prometheus    = "true"
    }
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 60
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "ceph_osd_down > 0"
        refId   = "A"
        instant = true
      })
    }
  }
}

resource "grafana_rule_group" "volsync" {
  name             = "volsync"
  folder_uid       = grafana_folder.storage.uid
  interval_seconds = 60

  rule {
    name = "VolsyncBackupFailed"
    annotations = {
      summary     = "Volsync backup job failed"
      description = "Backup for $${labels.name} in namespace $${labels.namespace} has failed"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "volsync_volume_out_of_sync == 1"
        refId   = "A"
        instant = true
      })
    }
  }
}

# =============================================================================
# PLATFORM - GitOps, Cert-Manager, External Secrets
# =============================================================================
resource "grafana_folder" "platform" {
  title = "Platform Services"
}

resource "grafana_rule_group" "flux" {
  name             = "flux"
  folder_uid       = grafana_folder.platform.uid
  interval_seconds = 60

  rule {
    name = "FluxReconciliationFailure"
    annotations = {
      summary     = "Flux reconciliation is failing"
      description = "$${labels.kind}/$${labels.name} in namespace $${labels.namespace} reconciliation is failing"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    for           = "15m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "gotk_reconcile_condition{type=\"Ready\", status=\"False\"} > 0"
        refId   = "A"
        instant = true
      })
    }
  }

  rule {
    name = "FluxSuspended"
    annotations = {
      summary     = "Flux resource is suspended"
      description = "$${labels.kind}/$${labels.name} in namespace $${labels.namespace} has been suspended for 24 hours"
    }
    labels = {
      severity                 = "info"
      depends_on_prometheus    = "true"
    }
    for           = "24h"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 86400
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "gotk_suspend_status > 0"
        refId   = "A"
        instant = true
      })
    }
  }
}

resource "grafana_rule_group" "external_secrets" {
  name             = "external-secrets"
  folder_uid       = grafana_folder.platform.uid
  interval_seconds = 60

  rule {
    name = "ExternalSecretSyncError"
    annotations = {
      summary     = "External Secret sync is failing"
      description = "ExternalSecret $${labels.name} in namespace $${labels.namespace} is failing to sync"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    for           = "15m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "externalsecret_status_condition{condition=\"Ready\", status=\"False\"} > 0"
        refId   = "A"
        instant = true
      })
    }
  }
}

resource "grafana_rule_group" "cert_manager" {
  name             = "cert-manager"
  folder_uid       = grafana_folder.platform.uid
  interval_seconds = 60

  rule {
    name = "CertificateExpiringSoon"
    annotations = {
      summary     = "Certificate expiring soon"
      description = "Certificate $${labels.name} in namespace $${labels.namespace} expires in less than 7 days"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "(certmanager_certificate_expiration_timestamp_seconds - time()) / 86400 < 7"
        refId   = "A"
        instant = true
      })
    }
  }

  rule {
    name = "CertificateNotReady"
    annotations = {
      summary     = "Certificate not ready"
      description = "Certificate $${labels.name} in namespace $${labels.namespace} is not ready"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    for           = "10m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "certmanager_certificate_ready_status{condition=\"False\"} == 1"
        refId   = "A"
        instant = true
      })
    }
  }
}

# =============================================================================
# APPLICATIONS - Media stack and critical services
# =============================================================================
resource "grafana_folder" "applications" {
  title = "Applications"
}

resource "grafana_rule_group" "critical_services" {
  name             = "critical-services"
  folder_uid       = grafana_folder.applications.uid
  interval_seconds = 60

  rule {
    name = "CriticalServiceDown"
    annotations = {
      summary     = "Critical service is down"
      description = "Service $${labels.app} is not responding"
    }
    labels = {
      severity = "critical"
    }
    for           = "5m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr    = "up{app=~\"authentik|home-assistant|gatus\"} == 0"
        refId   = "A"
        instant = true
      })
    }
  }

  rule {
    name = "HighResponseTime"
    annotations = {
      summary     = "Service has high response time"
      description = "Service $${labels.service} has response time > 5s"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    for           = "10m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "nginx_ingress_controller_request_duration_seconds{quantile=\"0.99\"} > 5"
        refId   = "A"
        instant = true
      })
    }
  }
}

resource "grafana_rule_group" "media_services" {
  name             = "media-services"
  folder_uid       = grafana_folder.applications.uid
  interval_seconds = 60

  rule {
    name = "PlexOffline"
    annotations = {
      summary     = "Plex Media Server is offline"
      description = "Plex has been unreachable for 10 minutes"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    for           = "10m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "up{app=\"plex\"} == 0"
        refId   = "A"
        instant = true
      })
    }
  }

  rule {
    name = "ArrServiceDown"
    annotations = {
      summary     = "*arr service is down"
      description = "Service $${labels.app} has been down for 5 minutes"
    }
    labels = {
      severity                 = "warning"
      depends_on_prometheus    = "true"
    }
    for           = "5m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "up{app=~\"sonarr|radarr|prowlarr|bazarr|lidarr\"} == 0"
        refId   = "A"
        instant = true
      })
    }
  }

  rule {
    name = "SABnzbdQueueStalled"
    annotations = {
      summary     = "SABnzbd download queue is stalled"
      description = "SABnzbd has items in queue but no active downloads for 30 minutes"
    }
    labels = {
      severity                 = "info"
      depends_on_prometheus    = "true"
    }
    for           = "30m"
    condition     = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 1800
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "sabnzbd_queue_size > 0 and sabnzbd_downloading_size == 0"
        refId   = "A"
        instant = true
      })
    }
  }
}