# Folder defined in folders.tf

resource "grafana_rule_group" "smartctl" {
  name             = "smartctl"
  folder_uid       = grafana_folder.storage.uid
  interval_seconds = 60

  rule {
    name        = "SmartDeviceHighTemperature"
    annotations = {
      summary     = "SMART device high temperature"
      description = "Device {{ $labels.device }} on {{ $labels.instance }} has temperature {{ $values.A }}°C"
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
      description = "Device {{ $labels.device }} on {{ $labels.instance }} test failed"
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
      description = "Device {{ $labels.device }} on {{ $labels.instance }} has critical warning"
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
      description = "Device {{ $labels.device }} on {{ $labels.instance }} has {{ $values.A }} media errors"
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
      description = "Device {{ $labels.device }} on {{ $labels.instance }} available spare under threshold"
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
