# Cluster Overview Dashboard - High-level cluster health view
resource "grafana_dashboard" "cluster_overview" {
  config_json = jsonencode({
    title = "🏠 Home-Ops Cluster Overview"
    tags  = ["cluster", "overview", "infrastructure"]
    time = {
      from = "now-1h"
      to   = "now"
    }
    refresh = "30s"
    
    templating = {
      list = [
        {
          name = "namespace"
          type = "query"
          query = "label_values(kube_namespace_created, namespace)"
          refresh = 1
          includeAll = true
          allValue = ".*"
          current = {
            selected = false
            text = "All"
            value = "$__all"
          }
        }
      ]
    }
    
    panels = [
      # Row 1: Infrastructure Health Overview
      {
        title = "🚀 Infrastructure Health"
        type  = "row"
        gridPos = { h = 1, w = 24, x = 0, y = 0 }
      }
      {
        title = "Cluster Status"
        type  = "stat"
        gridPos = { h = 6, w = 4, x = 0, y = 1 }
        targets = [
          {
            expr = "count(kube_node_info)"
            legendFormat = "Nodes"
            refId = "A"
          }
          {
            expr = "sum(kube_namespace_created)"
            legendFormat = "Namespaces"  
            refId = "B"
          }
          {
            expr = "count(kube_pod_info)"
            legendFormat = "Pods"
            refId = "C"
          }
        ]
        fieldConfig = {
          defaults = {
            mappings = []
            unit = "short"
            thresholds = {
              steps = [
                { color = "green", value = null }
              ]
            }
          }
        }
        options = {
          colorMode = "background"
          graphMode = "none"
          justifyMode = "center"
          orientation = "vertical"
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          textMode = "value_and_name"
        }
      }
      {
        title = "Flux Health"
        type  = "stat"  
        gridPos = { h = 6, w = 4, x = 4, y = 1 }
        targets = [
          {
            expr = "sum(gotk_reconcile_condition{type=\"Ready\",status=\"True\",kind=\"Kustomization\"})"
            legendFormat = "Kustomizations Ready"
            refId = "A"
          }
          {
            expr = "sum(gotk_reconcile_condition{type=\"Ready\",status=\"False\",kind=\"Kustomization\"})"
            legendFormat = "Kustomizations Failed"
            refId = "B"
          }
          {
            expr = "sum(gotk_reconcile_condition{type=\"Ready\",status=\"True\",kind=\"HelmRelease\"})"
            legendFormat = "HelmReleases Ready"
            refId = "C"
          }
          {
            expr = "sum(gotk_reconcile_condition{type=\"Ready\",status=\"False\",kind=\"HelmRelease\"})"
            legendFormat = "HelmReleases Failed"
            refId = "D"
          }
        ]
        fieldConfig = {
          defaults = {
            mappings = [
              {
                options = {
                  "0" = { text = "✅ All Good", color = "green" }
                }
                type = "value"
              }
            ]
            thresholds = {
              steps = [
                { color = "green", value = null }
                { color = "red", value = 1 }
              ]
            }
          }
        }
        options = {
          colorMode = "background"
          graphMode = "none"
          justifyMode = "center"
          orientation = "vertical"
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          textMode = "value_and_name"
        }
      }
      {
        title = "Workload Health"
        type  = "stat"
        gridPos = { h = 6, w = 4, x = 8, y = 1 }
        targets = [
          {
            expr = "sum(kube_pod_status_phase{phase=\"Running\"})"
            legendFormat = "Running Pods"
            refId = "A"
          }
          {
            expr = "sum(kube_pod_status_phase{phase!=\"Running\",phase!=\"Succeeded\"})"
            legendFormat = "Problem Pods"
            refId = "B"
          }
          {
            expr = "sum(kube_job_status_failed)"
            legendFormat = "Failed Jobs"
            refId = "C"
          }
        ]
        fieldConfig = {
          defaults = {
            mappings = [
              {
                options = {
                  "0" = { text = "✅ All Good", color = "green" }
                }
                type = "value"
              }
            ]
            thresholds = {
              steps = [
                { color = "green", value = null }
                { color = "yellow", value = 1 }
                { color = "red", value = 5 }
              ]
            }
          }
        }
        options = {
          colorMode = "background"
          graphMode = "none"
          justifyMode = "center"
          orientation = "vertical"
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          textMode = "value_and_name"
        }
      }
      {
        title = "Synthetic Monitoring"
        type  = "stat"
        gridPos = { h = 6, w = 4, x = 12, y = 1 }
        targets = [
          {
            expr = "avg(k6:checks_rate:avg) * 100"
            legendFormat = "Avg Success Rate"
            refId = "A"
          }
          {
            expr = "count(k6:checks_rate:avg < 0.95)"
            legendFormat = "Services Failing"
            refId = "B"
          }
        ]
        fieldConfig = {
          defaults = {
            mappings = [
              {
                options = {
                  "0" = { text = "✅ All Good", color = "green" }
                }
                type = "value"
              }
            ]
            unit = "percent"
            thresholds = {
              steps = [
                { color = "red", value = null }
                { color = "yellow", value = 95 }
                { color = "green", value = 99 }
              ]
            }
          }
        }
        options = {
          colorMode = "background"
          graphMode = "none"
          justifyMode = "center"
          orientation = "vertical"
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          textMode = "value_and_name"
        }
      }
      {
        title = "Resource Usage"
        type  = "stat"
        gridPos = { h = 6, w = 8, x = 16, y = 1 }
        targets = [
          {
            expr = "sum(rate(container_cpu_usage_seconds_total{container!=\"POD\",container!=\"\"}[5m]))"
            legendFormat = "CPU Usage (cores)"
            refId = "A"
          }
          {
            expr = "sum(container_memory_working_set_bytes{container!=\"POD\",container!=\"\"}) / 1024 / 1024 / 1024"
            legendFormat = "Memory Usage (GB)"
            refId = "B"
          }
          {
            expr = "sum(kubelet_volume_stats_used_bytes) / sum(kubelet_volume_stats_capacity_bytes) * 100"
            legendFormat = "Storage Usage (%)"
            refId = "C"
          }
        ]
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              steps = [
                { color = "green", value = null }
                { color = "yellow", value = 70 }
                { color = "red", value = 90 }
              ]
            }
          }
          overrides = [
            {
              matcher = { id = "byName", options = "CPU Usage (cores)" }
              properties = [{ id = "unit", value = "short" }]
            }
            {
              matcher = { id = "byName", options = "Memory Usage (GB)" }
              properties = [{ id = "unit", value = "decbytes" }]
            }
            {
              matcher = { id = "byName", options = "Storage Usage (%)" }
              properties = [{ id = "unit", value = "percent" }]
            }
          ]
        }
        options = {
          colorMode = "background"
          graphMode = "none"
          justifyMode = "center"
          orientation = "vertical"
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          textMode = "value_and_name"
        }
      }

      # Row 2: Service Health Matrix
      {
        title = "🎯 Service Health by Namespace"
        type  = "row"
        gridPos = { h = 1, w = 24, x = 0, y = 7 }
      }
      {
        title = "Pod Status Matrix"
        type  = "table"
        gridPos = { h = 8, w = 12, x = 0, y = 8 }
        targets = [
          {
            expr = "sum by (namespace, phase) (kube_pod_status_phase{namespace=~\"$namespace\"})"
            format = "table"
            refId = "A"
          }
        ]
        transformations = [
          {
            id = "groupBy"
            options = {
              fields = {
                namespace = { aggregation = [ "groupBy" ], operation = "groupBy" }
                phase = { aggregation = [ "groupBy" ], operation = "groupBy" }
                "Value #A" = { aggregation = [ "sum" ], operation = "aggregate" }
              }
            }
          }
          {
            id = "pivot"
            options = {
              columnField = "phase"
              rowFields = [ "namespace" ]
              valueField = "Value #A (sum)"
            }
          }
        ]
        fieldConfig = {
          defaults = {
            custom = {
              align = "center"
              displayMode = "color-background"
            }
            mappings = [
              {
                options = {
                  "null" = { text = "0", color = "transparent" }
                }
                type = "special"
              }
            ]
            thresholds = {
              steps = [
                { color = "green", value = null }
                { color = "yellow", value = 1 }
                { color = "red", value = 5 }
              ]
            }
          }
          overrides = [
            {
              matcher = { id = "byName", options = "Running" }
              properties = [
                {
                  id = "custom.displayMode"
                  value = "color-text"
                }
                {
                  id = "thresholds"
                  value = {
                    steps = [
                      { color = "green", value = null }
                    ]
                  }
                }
              ]
            }
          ]
        }
        options = {
          showHeader = true
          sortBy = [
            {
              desc = false
              displayName = "namespace"
            }
          ]
        }
      }
      {
        title = "Recent Events"
        type  = "logs"
        gridPos = { h = 8, w = 12, x = 12, y = 8 }
        targets = [
          {
            expr = "{job=\"eventrouter\"}"
            refId = "A"
          }
        ]
        options = {
          showTime = true
          showLabels = false
          showCommonLabels = false
          wrapLogMessage = false
          prettifyLogMessage = false
          enableLogDetails = true
          dedupStrategy = "none"
          sortOrder = "Descending"
        }
      }

      # Row 3: Resource Trends  
      {
        title = "📊 Resource Trends"
        type  = "row"
        gridPos = { h = 1, w = 24, x = 0, y = 16 }
      }
      {
        title = "CPU Usage by Namespace"
        type  = "timeseries"
        gridPos = { h = 8, w = 8, x = 0, y = 17 }
        targets = [
          {
            expr = "topk(10, sum by (namespace) (rate(container_cpu_usage_seconds_total{namespace=~\"$namespace\",container!=\"POD\",container!=\"\"}[5m])))"
            legendFormat = "{{ namespace }}"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "linear"
              barAlignment = 0
              lineWidth = 1
              fillOpacity = 10
              gradientMode = "none"
              spanNulls = false
              insertNulls = false
              showPoints = "never"
              pointSize = 5
              stacking = { mode = "none", group = "A" }
              axisPlacement = "auto"
              axisLabel = "CPU Cores"
              axisColorMode = "text"
              scaleDistribution = { type = "linear" }
              axisCenteredZero = false
              hideFrom = { legend = false, tooltip = false, vis = false }
              thresholdsStyle = { mode = "off" }
            }
            mappings = []
            unit = "short"
          }
        }
        options = {
          legend = {
            calcs = ["last"]
            displayMode = "table"
            placement = "right"
            showLegend = true
            width = 200
          }
          tooltip = { mode = "multi", sort = "desc" }
        }
      }
      {
        title = "Memory Usage by Namespace"
        type  = "timeseries"
        gridPos = { h = 8, w = 8, x = 8, y = 17 }
        targets = [
          {
            expr = "topk(10, sum by (namespace) (container_memory_working_set_bytes{namespace=~\"$namespace\",container!=\"POD\",container!=\"\"}))"
            legendFormat = "{{ namespace }}"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "linear"
              barAlignment = 0
              lineWidth = 1
              fillOpacity = 10
              gradientMode = "none"
              spanNulls = false
              insertNulls = false
              showPoints = "never"
              pointSize = 5
              stacking = { mode = "none", group = "A" }
              axisPlacement = "auto"
              axisLabel = "Memory"
              axisColorMode = "text"
              scaleDistribution = { type = "linear" }
              axisCenteredZero = false
              hideFrom = { legend = false, tooltip = false, vis = false }
              thresholdsStyle = { mode = "off" }
            }
            mappings = []
            unit = "bytes"
          }
        }
        options = {
          legend = {
            calcs = ["last"]
            displayMode = "table"
            placement = "right"
            showLegend = true
            width = 200
          }
          tooltip = { mode = "multi", sort = "desc" }
        }
      }
      {
        title = "Pod Restart Rate"
        type  = "timeseries"
        gridPos = { h = 8, w = 8, x = 16, y = 17 }
        targets = [
          {
            expr = "topk(10, sum by (namespace) (rate(kube_pod_container_status_restarts_total{namespace=~\"$namespace\"}[5m]) * 60))"
            legendFormat = "{{ namespace }}"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "linear"
              barAlignment = 0
              lineWidth = 1
              fillOpacity = 10
              gradientMode = "none"
              spanNulls = false
              insertNulls = false
              showPoints = "never"
              pointSize = 5
              stacking = { mode = "none", group = "A" }
              axisPlacement = "auto"
              axisLabel = "Restarts/min"
              axisColorMode = "text"
              scaleDistribution = { type = "linear" }
              axisCenteredZero = false
              hideFrom = { legend = false, tooltip = false, vis = false }
              thresholdsStyle = { mode = "off" }
            }
            mappings = []
            unit = "short"
          }
        }
        options = {
          legend = {
            calcs = ["last"]
            displayMode = "table"
            placement = "right"
            showLegend = true
            width = 200
          }
          tooltip = { mode = "multi", sort = "desc" }
        }
      }
    ]
  })
}