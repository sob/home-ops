# Folder defined in folders.tf

resource "grafana_rule_group" "ups" {
  name             = "ups"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 60

  rule {
    name        = "UPSOnBattery"
    annotations = {
      summary     = "UPS running on battery"
      description = "UPS rack-ups.stonehedges.net is running on battery power"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "30s"
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
        expr = "max by (instance) (upsBaseBatteryTimeOnBattery) > 0"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "UPSBatteryLow"
    annotations = {
      summary     = "UPS battery low"
      description = "UPS rack-ups.stonehedges.net battery is below 25% (current: {{ $values.A }}%)"
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
        expr = "min by (instance) (upsAdvanceBatteryCapacity) < 25"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "UPSBatteryReplaceNeeded"
    annotations = {
      summary     = "UPS battery needs replacement"
      description = "UPS rack-ups.stonehedges.net battery needs to be replaced"
    }
    labels = {
      severity = "warning"
      depends_on_prometheus = "true"
    }
    for      = "24h"
    condition = "A"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 86400
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "max by (instance) (upsAdvanceBatteryReplaceIndicator) == 2"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "UPSOverload"
    annotations = {
      summary     = "UPS overloaded"
      description = "UPS rack-ups.stonehedges.net load is above 80% (current: {{ $values.A }}%)"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "5m"
    condition = "A"
    no_data_state = "OK"  # When query returns no results (load < 80%), treat as Normal/OK

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "max by (instance) (upsAdvanceOutputLoad) > 80"
        refId = "A"
        instant = true      })
    }
  }

  rule {
    name        = "UPSCommunicationLost"
    annotations = {
      summary     = "Lost communication with UPS"
      description = "Cannot communicate with UPS rack-ups.stonehedges.net"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "2m"
    condition = "A"
    no_data_state = "OK"  # No results means device is up

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 120
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "up{job=\"snmp-exporter-cyberpower-ups\"} == 0 or absent(up{job=\"snmp-exporter-cyberpower-ups\"})"
        refId = "A"
        instant = true
      })
    }
  }

  rule {
    name        = "PDUCommunicationLost"
    annotations = {
      summary     = "Lost communication with PDU"
      description = "Cannot communicate with PDU rack-pdu.stonehedges.net"
    }
    labels = {
      severity = "critical"
      depends_on_prometheus = "true"
    }
    for      = "2m"
    condition = "A"
    no_data_state = "OK"  # No results means device is up

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 120
        to   = 0
      }
      
      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        expr = "up{job=\"snmp-exporter-cyberpower-pdu\"} == 0 or absent(up{job=\"snmp-exporter-cyberpower-pdu\"})"
        refId = "A"
        instant = true
      })
    }
  }
}

resource "grafana_rule_group" "pdu" {
  name             = "pdu"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 60

  rule {
    name        = "PDUHighLoad"
    annotations = {
      summary     = "PDU high load"
      description = "PDU rack-pdu.stonehedges.net load is above 90% (current: {{ $values.A }}dA = {{ div $values.A 10 }}A)"
    }
    labels = {
      severity = "warning"
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
        expr = "(ePDU2BankStatusLoad / 10) > 10.8"  # 12A PDU, alert at 90% (10.8A). Metric is in deciamps, divide by 10
        refId = "A"
        instant = true
      })
    }
  }
}