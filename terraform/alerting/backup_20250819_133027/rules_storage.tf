resource "grafana_folder" "storage" {
  title = "Storage"
}

resource "grafana_rule_group" "smartctl" {
  name             = "smartctl"
  folder_uid       = grafana_folder.storage.uid
  interval_seconds = 60

  rule {
    name        = "SmartDeviceHighTemperature"
    annotations = {
      summary     = "SMART device high temperature"
      description = "Device $${labels.device} on $${labels.instance} has temperature $${values.A}°C"
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
        expr = "max by (device, instance) (smartctl_device_temperature) > 60"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "SmartDeviceTestFailed"
    annotations = {
      summary     = "SMART device test failed"
      description = "Device $${labels.device} on $${labels.instance} test failed"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "0s"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 60
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "min by (device, instance) (smartctl_device_smart_status) != 1"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "SmartDeviceCriticalWarning"
    annotations = {
      summary     = "SMART device critical warning"
      description = "Device $${labels.device} on $${labels.instance} has critical warning"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "0s"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 60
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "max by (device, instance) (smartctl_device_critical_warning) != 0"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "SmartDeviceMediaErrors"
    annotations = {
      summary     = "SMART device media errors"
      description = "Device $${labels.device} on $${labels.instance} has $${values.A} media errors"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "0s"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 60
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "max by (device, instance) (smartctl_device_media_errors) > 0"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "SmartDeviceAvailableSpareUnderThreshold"
    annotations = {
      summary     = "SMART device spare capacity under threshold"
      description = "Device $${labels.device} on $${labels.instance} available spare under threshold"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "0s"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 60
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "max by (device, instance) (smartctl_device_available_spare_threshold - smartctl_device_available_spare) > 0"
        refId = "A"
        instant = true      })
    }
  }
}

resource "grafana_rule_group" "volsync" {
  name             = "volsync"
  folder_uid       = grafana_folder.storage.uid
  interval_seconds = 60

  rule {
    name        = "VolSyncBackupFailed"
    annotations = {
      summary     = "Backup failed"
      description = "VolSync backup for $${labels.name} in namespace $${labels.namespace} has failed"
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
        expr = "sum by (name, namespace) (increase(volsync_failures_total[1h])) > 0"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "VolSyncBackupOld"
    annotations = {
      summary     = "Backup is stale"
      description = "Volume $${labels.name} hasn't been backed up in 3 days"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "1h"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 3600
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "max by (name) (time() - volsync_volume_last_sync_time) > 259200"  # 3 days
        refId = "A"
        instant = true      })
    }
  }
}

resource "grafana_rule_group" "ceph" {
  name             = "ceph"
  folder_uid       = grafana_folder.storage.uid
  interval_seconds = 60

  rule {
    name        = "CephHealthError"
    annotations = {
      summary     = "Ceph cluster health error"
      description = "Ceph cluster is in ERROR state"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "1m"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 60
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "max(ceph_health_status) == 2"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "CephOSDDown"
    annotations = {
      summary     = "Ceph OSD down"
      description = "$${values.A} Ceph OSD(s) are down"
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
        expr = "sum(ceph_osd_down) > 0"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "CephPGsDegraded"
    annotations = {
      summary     = "Ceph PGs degraded"
      description = "$${values.A} PGs are in degraded state"
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
        expr = "sum(ceph_pg_degraded) > 0"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "CephPoolNearFull"
    annotations = {
      summary     = "Ceph pool near full"
      description = "Ceph pool $${labels.pool} is $${values.A}% full"
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
        expr = "max by (pool) ((ceph_pool_bytes_used / ceph_pool_max_avail) * 100) > 85"
        refId = "A"
        instant = true      })
    }
  }
}