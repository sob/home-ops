# Folder defined in folders.tf

resource "grafana_rule_group" "node_availability" {
  name             = "node-availability"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 60

  # Alert when any node is down (using blackbox ICMP probes)
  rule {
    name        = "NodeDown"
    annotations = {
      summary     = "Kubernetes node is down"  
      description = "Node {{ $labels.instance }} has been unreachable for 5 minutes"
    }
    labels = {
      severity = "critical"
    }
    for      = "5m"
    condition = "B"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model          = jsonencode({
        expr = "probe_success{probe_type=\"node_icmp\"}"
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


  # Alert when control plane node is down (using blackbox ICMP probes)
  rule {
    name        = "ControlPlaneNodeDown"
    annotations = {
      summary     = "Control plane node is down"
      description = "Control plane node {{ $labels.instance }} has been unreachable for 2 minutes"
    }
    labels = {
      severity = "critical"
    }
    for      = "2m"
    condition = "B"
    no_data_state = "OK"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 120
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model          = jsonencode({
        expr = "probe_success{probe_type=\"node_icmp\", instance=~\"10.1.100.10[1-3]\"}"
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

# Node health alerts removed - using blackbox probes for all node monitoring