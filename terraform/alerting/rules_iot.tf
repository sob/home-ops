# IoT Device Monitoring Alerts

resource "grafana_rule_group" "iot_availability" {
  name             = "iot-availability"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 60

  # Alert when IoT device is unreachable
  rule {
    name        = "IoTDeviceDown"
    annotations = {
      summary     = "IoT device is unreachable"  
      description = "{{ .Labels.instance }} has been unreachable for 10 minutes"
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
}