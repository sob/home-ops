# Off-cluster network & log-pipeline safety net.
#
# These rules live in Grafana Cloud (NOT in-cluster) so they keep firing even
# when the homelab / in-cluster Prometheus + Alertmanager are themselves down.
# They evaluate metrics Alloy already forwards to Grafana Cloud (blackbox node
# probes), giving an outside-in dead-man's switch for the whole observability
# pipeline. In-cluster device/log detail lives in the PrometheusRules under
# kubernetes/apps/observability/kube-prometheus-stack/app/rules/.

resource "grafana_rule_group" "network_safety_net" {
  name             = "network-safety-net"
  folder_uid       = grafana_folder.infrastructure.uid
  interval_seconds = 60

  # Dead-man's switch: if forwarded node probes stop arriving, the cluster's
  # metrics pipeline (Alloy → Cloud) is down — alert from outside.
  rule {
    name          = "MetricsForwardingDown"
    annotations = {
      summary     = "Homelab metrics forwarding to Grafana Cloud has stopped"
      description = "No blackbox node-probe samples have reached Grafana Cloud for 10m. The cluster, Alloy, or the WAN uplink is likely down."
    }
    labels = {
      severity = "critical"
      type     = "network"
    }
    for           = "10m"
    condition     = "B"
    no_data_state = "Alerting"

    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr    = "count(up{job=\"blackbox-node-probes\"})"
        refId   = "A"
        instant = true
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        type       = "math"
        expression = "$A < 1"
        refId      = "B"
      })
    }
  }

  # All Kubernetes nodes unreachable from the probe vantage point = major outage.
  rule {
    name          = "AllNodesUnreachable"
    annotations = {
      summary     = "All homelab nodes are unreachable"
      description = "Every forwarded node ICMP probe is failing — likely a full cluster, switch, or power outage."
    }
    labels = {
      severity = "critical"
      type     = "network"
    }
    for           = "5m"
    condition     = "B"
    no_data_state = "Alerting"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr    = "sum(probe_success{probe_type=\"node_icmp\"})"
        refId   = "A"
        instant = true
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        type       = "math"
        expression = "$A < 1"
        refId      = "B"
      })
    }
  }
}
