resource "grafana_dashboard" "power_ups" {
  config_json = jsonencode({
    title = "Power & UPS Monitoring"
    description = "Monitor UPS and PDU status, battery health, and power consumption"
    timezone = "browser"
    schemaVersion = 39
    version = 1
    refresh = "30s"
    time = {
      from = "now-6h"
      to = "now"
    }
    
    templating = {
      list = []
    }
    
    panels = [
      # UPS Section Header
      {
        gridPos = { h = 1, w = 24, x = 0, y = 0 }
        id = 200
        type = "row"
        title = "UPS - CyberPower OR1500PFCLCD (rack-ups.stonehedges.net)"
        collapsed = false
      },
      
      # UPS Status Row
      {
        gridPos = { h = 4, w = 4, x = 0, y = 1 }
        id = 101
        type = "stat"
        title = "UPS Status"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(up{job=\"snmp-exporter-cyberpower-ups\"})"
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
                    text = "Offline"
                    index = 0
                  }
                  "1" = { 
                    text = "Online"
                    index = 1
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
            color = {
              mode = "thresholds"
            }
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
        id = 103
        type = "stat"
        title = "Power Source"
        description = "Shows 'Grid' when on mains power, or time in seconds when running on battery"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(upsBaseBatteryTimeOnBattery)"
            legendFormat = "Time on Battery"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            mappings = [
              {
                options = {
                  "0" = {
                    text = "Grid"
                    color = "green"
                  }
                }
                type = "value"
              }
            ]
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 1, color = "yellow" },
                { value = 60, color = "red" }
              ]
            }
            unit = "s"
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
          textMode = "auto"
          colorMode = "value"
          graphMode = "none"
          justifyMode = "auto"
        }
      },
      {
        gridPos = { h = 4, w = 4, x = 8, y = 1 }
        id = 4
        type = "gauge"
        title = "Battery Charge"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(upsAdvanceBatteryCapacity)"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            max = 100
            min = 0
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "red" },
                { value = 25, color = "orange" },
                { value = 50, color = "yellow" },
                { value = 75, color = "green" }
              ]
            }
            unit = "percent"
          }
        }
      },
      {
        gridPos = { h = 4, w = 3, x = 12, y = 1 }
        id = 111
        type = "stat"
        title = "Battery Status"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(upsAdvanceBatteryReplaceIndicator)"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            mappings = [
              {
                options = {
                  "1" = {
                    text = "OK"
                    color = "green"
                  }
                  "2" = {
                    text = "REPLACE"
                    color = "red"
                  }
                }
                type = "value"
              }
            ]
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 1, color = "red" }
              ]
            }
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
        gridPos = { h = 4, w = 6, x = 15, y = 1 }
        id = 8
        type = "stat"
        title = "Runtime"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(upsAdvanceBatteryRunTimeRemaining) / 60"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "m"
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "red" },
                { value = 5, color = "orange" },
                { value = 15, color = "yellow" },
                { value = 30, color = "green" }
              ]
            }
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
          textMode = "auto"
          colorMode = "value"
          graphMode = "none"
          justifyMode = "auto"
        }
      },
      {
        gridPos = { h = 4, w = 3, x = 21, y = 1 }
        id = 201
        type = "stat"
        title = "Load"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(upsAdvanceOutputLoad)"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "percent"
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 50, color = "yellow" },
                { value = 80, color = "red" }
              ]
            }
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
          textMode = "auto"
          colorMode = "value"
          graphMode = "none"
          justifyMode = "auto"
        }
      },
      
      # UPS Charts Row
      {
        gridPos = { h = 8, w = 8, x = 0, y = 5 }
        id = 5
        type = "timeseries"
        title = "Load History"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(upsAdvanceOutputLoad)"
            legendFormat = "Load %"
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
            max = 100
            min = 0
            unit = "percent"
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 50, color = "yellow" },
                { value = 80, color = "red" }
              ]
            }
          }
        }
      },
      {
        gridPos = { h = 8, w = 8, x = 8, y = 5 }
        id = 7
        type = "timeseries"
        title = "Input/Output Voltage"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(upsAdvanceInputLineVoltage) / 10"
            legendFormat = "Input Voltage"
            refId = "A"
          },
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(upsAdvanceOutputVoltage) / 10"
            legendFormat = "Output Voltage"
            refId = "B"
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
              spanNulls = true
            }
            unit = "volt"
            min = 110
            max = 125
            decimals = 1
          }
        }
      },
      {
        gridPos = { h = 8, w = 8, x = 16, y = 5 }
        id = 110
        type = "timeseries"
        title = "Battery Capacity"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(upsAdvanceBatteryCapacity)"
            legendFormat = "Battery %"
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
            }
            max = 100
            min = 0
            unit = "percent"
          }
        }
      },
      
      # PDU Section Header
      {
        gridPos = { h = 1, w = 24, x = 0, y = 13 }
        id = 202
        type = "row"
        title = "PDU - CyberPower PDU41005 (rack-pdu.stonehedges.net)"
        collapsed = false
      },
      
      # PDU Status Row
      {
        gridPos = { h = 4, w = 4, x = 0, y = 14 }
        id = 102
        type = "stat"
        title = "PDU Status"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(up{job=\"snmp-exporter-cyberpower-pdu\"})"
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
                    text = "Offline"
                    index = 0
                  }
                  "1" = { 
                    text = "Online"
                    index = 1
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
            color = {
              mode = "thresholds"
            }
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
        gridPos = { h = 4, w = 4, x = 4, y = 14 }
        id = 203
        type = "stat"
        title = "Current Load"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(ePDU2BankStatusLoad)"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            unit = "amp"
            decimals = 1
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 10, color = "yellow" },
                { value = 12, color = "red" }
              ]
            }
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
          textMode = "auto"
          colorMode = "value"
          graphMode = "none"
          justifyMode = "auto"
        }
      },
      {
        gridPos = { h = 4, w = 6, x = 8, y = 14 }
        id = 204
        type = "gauge"
        title = "Load Percentage"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "(max(ePDU2BankStatusLoad) / 15) * 100"
            refId = "A"
          }
        ]
        fieldConfig = {
          defaults = {
            max = 100
            min = 0
            unit = "percent"
            decimals = 0
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 80, color = "yellow" },
                { value = 90, color = "red" }
              ]
            }
          }
        }
      },
      
      # PDU Charts Row
      {
        gridPos = { h = 8, w = 14, x = 0, y = 18 }
        id = 6
        type = "timeseries"
        title = "Load History"
        targets = [
          {
            datasource = {
              type = "prometheus"
              uid = local.prometheus_pdc_uid
            }
            expr = "max(ePDU2BankStatusLoad)"
            legendFormat = "Load (Amps)"
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
            unit = "amp"
            thresholds = {
              mode = "absolute"
              steps = [
                { value = 0, color = "green" },
                { value = 10, color = "yellow" },
                { value = 12, color = "red" }
              ]
            }
          }
        }
      },
    ]
  })
  
  folder = grafana_folder.power.id
}