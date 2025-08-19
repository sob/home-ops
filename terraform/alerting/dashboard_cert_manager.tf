resource "grafana_dashboard" "cert_manager" {
  config_json = jsonencode({
    title = "Cert-Manager"
    description = "Monitor certificate status, expiration, and renewal processes"
    timezone = "browser"
    schemaVersion = 39
    version = 1
    refresh = "30s"
    time = {
      from = "now-24h"
      to = "now"
    }
    
    templating = {
      list = []
    }
    
    panels = [
      # Overview Section
      {
        gridPos = { h = 1, w = 24, x = 0, y = 0 }
        id = 100
        type = "row"
        title = "Certificate Overview"
        collapsed = false
      },
      
      # Certificate counts
      {
        gridPos = { h = 4, w = 4, x = 0, y = 1 }
        id = 6
        type = "stat"
        title = "Cert-Manager Status"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "min(up{job=\"cert-manager\"})"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            mappings = [
              {
                type = "value"
                options = {
                  "0" = {
                    text = "Down"
                    color = "red"
                  }
                  "1" = {
                    text = "Up"
                    color = "green"
                  }
                }
              }
            ]
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "red" },
                { value = 1, color = "green" }
              ]
            }
            unit = "none"
          }
          overrides = []
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          orientation = "auto"
          textMode = "value"
          colorMode = "value"
          graphMode = "none"
          justifyMode = "auto"
        }
      },
      {
        gridPos = { h = 4, w = 4, x = 4, y = 1 }
        id = 1
        type = "stat"
        title = "Total Certificates"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "count(certmanager_certificate_expiration_timestamp_seconds)"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" }
              ]
            }
            unit = "none"
            decimals = 0
          }
          overrides = []
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          orientation = "auto"
          textMode = "value"
          colorMode = "value"
          graphMode = "none"
          justifyMode = "auto"
        }
      },
      {
        gridPos = { h = 4, w = 4, x = 8, y = 1 }
        id = 2
        type = "stat"
        title = "Ready Certificates"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "sum(certmanager_certificate_ready_status{condition=\"True\"})"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "red" },
                { value = 1, color = "green" }
              ]
            }
            unit = "none"
            decimals = 0
          }
          overrides = []
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          orientation = "auto"
          textMode = "value"
          colorMode = "value"
          graphMode = "none"
          justifyMode = "auto"
        }
      },
      {
        gridPos = { h = 4, w = 4, x = 12, y = 1 }
        id = 3
        type = "stat"
        title = "Not Ready"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "count(certmanager_certificate_expiration_timestamp_seconds) - sum(certmanager_certificate_ready_status{condition=\"True\"})"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 1, color = "yellow" },
                { value = 3, color = "red" }
              ]
            }
            unit = "none"
            decimals = 0
          }
          overrides = []
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          orientation = "auto"
          textMode = "value"
          colorMode = "value"
          graphMode = "none"
          justifyMode = "auto"
        }
      },
      {
        gridPos = { h = 4, w = 4, x = 16, y = 1 }
        id = 4
        type = "stat"
        title = "Expiring Soon (<30d)"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "sum((certmanager_certificate_expiration_timestamp_seconds - time() < 2592000) * (certmanager_certificate_expiration_timestamp_seconds - time() > 0)) or vector(0)"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 1, color = "yellow" },
                { value = 3, color = "orange" },
                { value = 5, color = "red" }
              ]
            }
            unit = "none"
            decimals = 0
          }
          overrides = []
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          orientation = "auto"
          textMode = "value"
          colorMode = "value"
          graphMode = "none"
          justifyMode = "auto"
        }
      },
      {
        gridPos = { h = 4, w = 4, x = 20, y = 1 }
        id = 5
        type = "stat"
        title = "Expired"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "sum(certmanager_certificate_expiration_timestamp_seconds - time() < 0) or vector(0)"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 1, color = "red" }
              ]
            }
            unit = "none"
            decimals = 0
          }
          overrides = []
        }
        options = {
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
          orientation = "auto"
          textMode = "value"
          colorMode = "value"
          graphMode = "none"
          justifyMode = "auto"
        }
      },
      
      # Certificate Details Section
      {
        gridPos = { h = 1, w = 24, x = 0, y = 5 }
        id = 101
        type = "row"
        title = "Certificate Details"
        collapsed = false
      },
      
      # Certificate status table
      {
        gridPos = { h = 10, w = 12, x = 0, y = 6 }
        id = 7
        type = "table"
        title = "Certificate Status"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max by (namespace, name) ((certmanager_certificate_expiration_timestamp_seconds - time()) / 86400)"
            format = "table"
            instant = true
            refId = "A"
          },
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max by (namespace, name) (certmanager_certificate_expiration_timestamp_seconds * 1000)"
            format = "table"
            instant = true
            refId = "B"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = {
              align = "auto"
              displayMode = "auto"
              inspect = false
            }
          }
          overrides = [
            {
              matcher = { id = "byName", options = "namespace" }
              properties = [
                {
                  id = "custom.width"
                  value = 150
                }
              ]
            },
            {
              matcher = { id = "byName", options = "name" }
              properties = [
                {
                  id = "custom.width"
                  value = 300
                }
              ]
            },
            {
              matcher = { id = "byName", options = "Value #A" }
              properties = [
                {
                  id = "displayName"
                  value = "Days Until Expiry"
                },
                {
                  id = "unit"
                  value = "short"
                },
                {
                  id = "decimals"
                  value = 0
                },
                {
                  id = "custom.width"
                  value = 150
                },
                {
                  id = "thresholds"
                  value = {
                    mode = "absolute"
                    steps = [
                      { value = 0, color = "red" },
                      { value = 7, color = "orange" },
                      { value = 30, color = "yellow" },
                      { value = 60, color = "green" }
                    ]
                  }
                },
                {
                  id = "custom.displayMode"
                  value = "color-background"
                }
              ]
            },
            {
              matcher = { id = "byName", options = "Value #B" }
              properties = [
                {
                  id = "displayName"
                  value = "Expiration Date"
                },
                {
                  id = "unit"
                  value = "dateTimeAsIso"
                },
                {
                  id = "custom.width"
                  value = 200
                }
              ]
            },
            {
              matcher = { id = "byName", options = "Time" }
              properties = [
                {
                  id = "custom.hidden"
                  value = true
                }
              ]
            }
          ]
        }
        options = {
          showHeader = true
          footer = {
            show = false
            reducer = ["sum"]
            fields = ""
          }
          frameIndex = 0
          sortBy = [
            {
              displayName = "Days Until Expiry"
              desc = false
            }
          ]
        }
        transformations = [
          {
            id = "merge"
            options = {}
          },
          {
            id = "organize"
            options = {
              excludeByName = {
                "Time" = true
                "condition" = true
                "exported_namespace" = true
                "issuer_group" = true
                "issuer_kind" = true
                "issuer_name" = true
                "job" = true
              }
              renameByName = {}
              indexByName = {
                "namespace" = 0
                "name" = 1
                "Value #A" = 2
                "Value #B" = 3
              }
            }
          }
        ]
      },
      
      # ACME Operations Section
      {
        gridPos = { h = 1, w = 24, x = 0, y = 16 }
        id = 102
        type = "row"
        title = "ACME Operations"
        collapsed = false
      },
      
      # Days until expiration bar chart
      {
        gridPos = { h = 10, w = 12, x = 12, y = 6 }
        id = 8
        type = "barchart"
        title = "Days Until Expiration"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "sort(round(max by (namespace, name) ((certmanager_certificate_expiration_timestamp_seconds - time()) / 86400)))"
            format = "table"
            instant = true
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = {
              axisCenteredZero = false
              axisLabel = "Days Until Expiration"
              axisPlacement = "bottom"
              fillOpacity = 95
              gradientMode = "none"
              hideFrom = {
                tooltip = false
                viz = false
                legend = false
              }
              lineWidth = 0
              scaleDistribution = {
                type = "linear"
              }
              barAlignment = 0
              thresholdsStyle = {
                mode = "color"
              }
            }
            unit = "short"
            decimals = 0
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "red" },
                { value = 7, color = "orange" },
                { value = 30, color = "yellow" },
                { value = 60, color = "green" }
              ]
            }
            mappings = []
          }
          overrides = [
            {
              matcher = { id = "byType", options = "number" }
              properties = [
                {
                  id = "unit"
                  value = "none"
                },
                {
                  id = "custom.neutral"
                  value = 0
                }
              ]
            }
          ]
        }
        options = {
          orientation = "horizontal"
          xTickLabelRotation = 0
          xTickLabelSpacing = 100
          showValue = "auto"
          stacking = "none"
          groupWidth = 0.4
          barWidth = 0.5
          barRadius = 2
          fullHighlight = false
          tooltip = {
            mode = "single"
            sort = "none"
          }
          legend = {
            showLegend = false
            displayMode = "list"
            placement = "bottom"
            calcs = []
          }
          text = {
            valueSize = 20
            titleSize = 14
          }
          thresholds = {
            style = {
              mode = "off"
            }
          }
        }
        transformations = [
          {
            id = "organize"
            options = {
              excludeByName = {
                "Time" = true
              }
              indexByName = {}
              renameByName = {}
            }
          }
        ]
      },
      
      # ACME solver attempts
      {
        gridPos = { h = 8, w = 12, x = 0, y = 17 }
        id = 10
        type = "timeseries"
        title = "ACME HTTP01 Solver Attempts"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "sum(rate(certmanager_http_acme_client_request_count[1h])) by (status)"
            legendFormat = "{{status}}"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "smooth"
              lineWidth = 2
              fillOpacity = 10
              showPoints = "never"
            }
            unit = "reqps"
            decimals = 4
          }
        }
      },
      
      # ACME Operations Breakdown
      {
        gridPos = { h = 8, w = 12, x = 12, y = 17 }
        id = 11
        type = "piechart"
        title = "ACME Operations Breakdown"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "sum by (path) (increase(certmanager_http_acme_client_request_count[24h]))"
            legendFormat = "{{path}}"
            instant = true
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            mappings = [
              {
                options = {
                  "/directory" = {
                    text = "Directory Lookups"
                    index = 0
                  }
                  "/acme/new-nonce" = {
                    text = "Nonce Requests"
                    index = 1
                  }
                  "/acme/new-acct" = {
                    text = "New Accounts"
                    index = 2
                  }
                  "/acme/acct" = {
                    text = "Account Operations"
                    index = 3
                  }
                }
                type = "value"
              }
            ]
            unit = "short"
            decimals = 0
          }
          overrides = []
        }
        options = {
          tooltip = {
            mode = "single"
            sort = "none"
          }
          legend = {
            displayMode = "table"
            placement = "right"
            showLegend = true
            values = ["value", "percent"]
          }
          pieType = "donut"
          displayLabels = ["name", "percent"]
          reduceOptions = {
            values = false
            calcs = ["lastNotNull"]
            fields = ""
          }
        }
      },
      
      # ACME Success Rate
      {
        gridPos = { h = 8, w = 12, x = 12, y = 25 }
        id = 14
        type = "timeseries"
        title = "ACME Request Success Rate"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "sum(rate(certmanager_http_acme_client_request_count{status=~\"2..\"}[1h])) / sum(rate(certmanager_http_acme_client_request_count[1h])) * 100"
            legendFormat = "Success Rate"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "smooth"
              lineWidth = 2
              fillOpacity = 20
              showPoints = "never"
              spanNulls = true
            }
            unit = "percent"
            min = 0
            max = 100
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "red" },
                { value = 50, color = "orange" },
                { value = 80, color = "yellow" },
                { value = 95, color = "green" }
              ]
            }
          }
        }
      },
      
      # ACME Request Activity
      {
        gridPos = { h = 8, w = 12, x = 0, y = 25 }
        id = 9
        type = "timeseries"
        title = "ACME Request Activity"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "sum(increase(certmanager_http_acme_client_request_count[1h])) by (status)"
            legendFormat = "Status {{status}}"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "bars"
              lineInterpolation = "linear"
              barAlignment = 0
              lineWidth = 1
              fillOpacity = 50
              gradientMode = "none"
              spanNulls = false
              showPoints = "never"
              pointSize = 5
              stacking = {
                mode = "none"
                group = "A"
              }
              axisPlacement = "auto"
              axisLabel = ""
              axisColorMode = "text"
              scaleDistribution = {
                type = "linear"
              }
              axisCenteredZero = false
              hideFrom = {
                tooltip = false
                viz = false
                legend = false
              }
              thresholdsStyle = {
                mode = "off"
              }
            }
            unit = "short"
            decimals = 0
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "text" },
                { value = 1, color = "green" }
              ]
            }
          }
        }
      },
      
      # Cert-Manager Logs
      {
        gridPos = { h = 8, w = 24, x = 0, y = 33 }
        id = 15
        type = "logs"
        title = "Cert-Manager Error Logs"
        targets = [
          {
            datasource = {
              type = "loki"
              uid = local.loki_metal_uid
            }
            expr = "{namespace=\"cert-manager\", pod=~\"cert-manager-.*\"} |~ \"error|ERROR|failed|FAILED|warn|WARN\""
            refId = "A"
          }
        ]
        options = {
          showTime = true
          showLabels = false
          showCommonLabels = false
          wrapLogMessage = true
          prettifyLogMessage = false
          enableLogDetails = true
          sortOrder = "Descending"
          dedupStrategy = "none"
        }
      },
      
      # System Health Section
      {
        gridPos = { h = 1, w = 24, x = 0, y = 41 }
        id = 104
        type = "row"
        title = "System Health"
        collapsed = false
      },
      
      # Clock skew
      {
        gridPos = { h = 8, w = 12, x = 0, y = 42 }
        id = 13
        type = "gauge"
        title = "Clock Skew"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "avg(certmanager_clock_time_seconds_gauge - time())"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            max = 10
            min = -10
            thresholds = {
              mode = "absolute"
              steps = [
                { value = -5, color = "red" },
                { value = -1, color = "yellow" },
                { value = 1, color = "green" },
                { value = 5, color = "yellow" },
                { value = 10, color = "red" }
              ]
            }
            unit = "s"
          }
        }
      }
    ]
  })
  
  folder = grafana_folder.applications.id
}