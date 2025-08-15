resource "grafana_folder" "power" {
  title = "Power & UPS"
}

resource "grafana_rule_group" "ups" {
  name             = "ups"
  folder_uid       = grafana_folder.power.uid
  interval_seconds = 60

  rule {
    name        = "UPSOnBattery"
    annotations = {
      summary     = "UPS running on battery"
      description = "UPS $${labels.ups} is running on battery power"
    }
    labels = {
      severity = "critical"
    }
    for      = "30s"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 60
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "upsOnBattery == 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  rule {
    name        = "UPSBatteryLow"
    annotations = {
      summary     = "UPS battery low"
      description = "UPS $${labels.ups} battery is below 25% (current: $${values.A.Value}%)"
    }
    labels = {
      severity = "critical"
    }
    for      = "1m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 60
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "upsBatteryChargePercent < 25"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  rule {
    name        = "UPSBatteryReplaceNeeded"
    annotations = {
      summary     = "UPS battery needs replacement"
      description = "UPS $${labels.ups} battery needs to be replaced"
    }
    labels = {
      severity = "warning"
    }
    for      = "24h"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 86400
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "upsBatteryReplaceIndicator == 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  rule {
    name        = "UPSOverload"
    annotations = {
      summary     = "UPS overloaded"
      description = "UPS $${labels.ups} load is above 80% (current: $${values.A.Value}%)"
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
        expr = "upsLoadPercent > 80"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  rule {
    name        = "UPSCommunicationLost"
    annotations = {
      summary     = "Lost communication with UPS"
      description = "Cannot communicate with UPS $${labels.ups}"
    }
    labels = {
      severity = "critical"
    }
    for      = "2m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 120
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "up{job=~\"snmp-exporter-cyberpower.*\"} == 0"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }
}

resource "grafana_rule_group" "pdu" {
  name             = "pdu"
  folder_uid       = grafana_folder.power.uid
  interval_seconds = 60

  rule {
    name        = "PDUHighLoad"
    annotations = {
      summary     = "PDU high load"
      description = "PDU $${labels.instance} load is above 80% (current: $${values.A.Value}A)"
    }
    labels = {
      severity = "warning"
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
        expr = "ePDULoadStatusLoad / 10 > 12"  # Assuming 15A PDU, alert at 80% (12A)
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }
}