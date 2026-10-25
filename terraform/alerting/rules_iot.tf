# IoT Device Monitoring Alerts

resource "grafana_rule_group" "iot_availability" {
  name             = "iot-availability"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 60

  # Alert when Chamberlain MyQ is disconnected from UniFi
  rule {
    name        = "ChamberlainMyQOffline"
    annotations = {
      summary     = "Chamberlain MyQ garage door opener is offline"
      description = "MyQ device has been disconnected from WiFi for 10 minutes"
    }
    labels = {
      severity = "critical"
      device   = "chamberlain-myq"
    }
    for      = "10m"
    condition = "B"
    no_data_state = "Alerting"  # Alert if no data (UniFi poller down)

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = local.prometheus_pdc_uid
      model          = jsonencode({
        # Monitor Chamberlain MyQ by MAC address (ethernet connected)
        expr = "unpoller_client_uptime_seconds{mac=\"64:52:99:07:a8:59\"}"
        refId = "A"
        instant = true
      })
    }

    data {
      ref_id = "B"

      datasource_uid = "__expr__"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type = "math"
        expression = "$A < 1"  # Device offline (no metric or value is 0)
        refId = "B"
      })
    }
  }

  # Alert when IoT device is unreachable (keeping existing for other devices)
  rule {
    name        = "IoTDeviceDown"
    annotations = {
      summary     = "IoT device is unreachable"
      description = "{{ $labels.instance }} has been unreachable for 10 minutes"
    }
    labels = {
      severity = "warning"
    }
    for      = "10m"
    condition = "B"
    no_data_state = "OK"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = local.prometheus_cloud_uid
      model          = jsonencode({
        expr = "probe_success{probe_type=\"iot_icmp\"}"
        refId = "A"
        instant = true
      })
    }

    data {
      ref_id = "B"

      datasource_uid = "__expr__"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type = "math"
        expression = "$A == 0"
        refId = "B"
      })
    }
  }

  # Alert when Sonos speaker is unreachable
  rule {
    name        = "SonosDeviceDown"
    annotations = {
      summary     = "Sonos speaker is unreachable"
      description = "Sonos {{ $labels.instance }} has been unreachable for 15 minutes"
    }
    labels = {
      severity = "warning"
      instance = "{{ $labels.instance }}"
    }
    for      = "15m"
    condition = "B"
    no_data_state = "OK"

    data {
      ref_id = "A"

      relative_time_range {
        from = 900
        to   = 0
      }

      datasource_uid = local.prometheus_cloud_uid
      model          = jsonencode({
        expr = "probe_success{probe_type=\"sonos_icmp\"}"
        refId = "A"
        instant = true
      })
    }

    data {
      ref_id = "B"

      datasource_uid = "__expr__"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type = "math"
        expression = "$A == 0"
        refId = "B"
      })
    }
  }
}

# Shelly plugs that must stay on. The plugs have auto_on (60s), so an output
# still off after 3 minutes means auto_on failed or something keeps switching
# it off. The MQTT audit log (Loki: {container="audit"}) shows the source.
resource "grafana_rule_group" "iot_critical_plugs" {
  name             = "iot-critical-plugs"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 60

  rule {
    name = "CriticalPlugOff"
    annotations = {
      summary     = "Critical plug is switched off"
      description = "{{ $labels.topic }} has been off for 3 minutes"
    }
    labels = {
      severity = "critical"
    }
    for           = "3m"
    condition     = "B"
    no_data_state = "OK"

    data {
      ref_id = "A"

      relative_time_range {
        from = 300
        to   = 0
      }

      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "mqtt_output{topic=~\"shelly_(garage-freezer|garage-fridge|sump-pump)_status_switch:0\"}"
        refId   = "A"
        instant = true
      })
    }

    data {
      ref_id = "B"

      datasource_uid = "__expr__"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "math"
        expression = "$A == 0"
        refId      = "B"
      })
    }
  }

  # The broker publishes the plug's last will (online=false) when it drops off.
  rule {
    name = "CriticalPlugOffline"
    annotations = {
      summary     = "Critical plug is offline"
      description = "{{ $labels.topic }} has been disconnected from MQTT for 10 minutes"
    }
    labels = {
      severity = "critical"
    }
    for           = "10m"
    condition     = "B"
    no_data_state = "OK"

    data {
      ref_id = "A"

      relative_time_range {
        from = 600
        to   = 0
      }

      datasource_uid = local.prometheus_pdc_uid
      model = jsonencode({
        expr    = "mqtt_online{topic=~\"shelly_(garage-freezer|garage-fridge|sump-pump)\"}"
        refId   = "A"
        instant = true
      })
    }

    data {
      ref_id = "B"

      datasource_uid = "__expr__"

      relative_time_range {
        from = 0
        to   = 0
      }

      model = jsonencode({
        type       = "math"
        expression = "$A == 0"
        refId      = "B"
      })
    }
  }
}
