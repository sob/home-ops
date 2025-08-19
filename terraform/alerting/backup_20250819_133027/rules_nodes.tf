resource "grafana_folder" "nodes" {
  title = "Kubernetes Nodes"
}

resource "grafana_rule_group" "node_availability" {
  name             = "node-availability"
  folder_uid       = grafana_folder.nodes.uid
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

# Node health alerts removed - using blackbox probes for all node monitoring