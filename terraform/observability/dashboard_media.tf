data "grafana_folder" "applications" {
  title = "Applications"
}

resource "grafana_dashboard" "media_services" {
  config_json = jsonencode({
    title       = "Media Services Performance"
    description = "Performance metrics and health monitoring for Plex, Jellyfin, and the *arr stack"
    uid         = "media-services-perf"
    version     = 1
    timezone    = "browser"
    schemaVersion = 39
    
    time = {
      from = "now-6h"
      to   = "now"
    }
    
    timepicker = {
      refresh_intervals = ["10s", "30s", "1m", "5m", "15m", "30m", "1h", "2h", "1d"]
    }
    
    templating = {
      list = [
        {
          name       = "prometheus"
          type       = "datasource"
          query      = "prometheus"
          current    = {
            text  = "prometheus-metal"
            value = "prometheus-metal"
          }
          hide       = 0
          refresh    = 1
          regex      = ""
        },
        {
          name       = "service"
          type       = "query"
          datasource = "$prometheus"
          query      = "label_values(up{namespace=\"media\"}, job)"
          current    = {
            selected = true
            text     = ["All"]
            value    = ["$__all"]
          }
          hide       = 0
          includeAll = true
          multi      = true
          refresh    = 2
          regex      = ""
          sort       = 1
        }
      ]
    }
    
    annotations = {
      list = [
        {
          builtIn    = 1
          datasource = {
            type = "datasource"
            uid  = "grafana"
          }
          enable     = true
          hide       = true
          iconColor  = "rgba(0, 211, 255, 1)"
          name       = "Annotations & Alerts"
          type       = "dashboard"
        }
      ]
    }
    
    panels = [
      # Row: Service Health Overview
      {
        type      = "row"
        title     = "Service Health Overview"
        gridPos   = { h = 1, w = 24, x = 0, y = 0 }
        id        = 1
        collapsed = false
      },
      
      # Service Availability
      {
        type = "stat"
        title = "Services"
        gridPos = { h = 4, w = 4, x = 0, y = 1 }
        id = 2
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            # Count healthy services using pod metrics
            expr = "count(pod:cpu_usage_millicores{namespace=\"default\", workload=~\"jellyfin|jellyseerr|lidarr|overseerr|plex|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli\"} > 0) or vector(0)"
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
                    text = "0/11"
                    color = "red"
                  }
                  "1" = {
                    text = "1/11"
                    color = "red"
                  }
                  "2" = {
                    text = "2/11"
                    color = "red"
                  }
                  "3" = {
                    text = "3/11"
                    color = "red"
                  }
                  "4" = {
                    text = "4/11"
                    color = "red"
                  }
                  "5" = {
                    text = "5/11"
                    color = "orange"
                  }
                  "6" = {
                    text = "6/11"
                    color = "orange"
                  }
                  "7" = {
                    text = "7/11"
                    color = "orange"
                  }
                  "8" = {
                    text = "8/11"
                    color = "yellow"
                  }
                  "9" = {
                    text = "9/11"
                    color = "yellow"
                  }
                  "10" = {
                    text = "10/11"
                    color = "yellow"
                  }
                  "11" = {
                    text = "OK"
                    color = "green"
                  }
                }
              }
            ]
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "red", value = null },
                { color = "orange", value = 5 },
                { color = "yellow", value = 8 },
                { color = "green", value = 11 }
              ]
            }
            unit = "none"
            color = { mode = "thresholds" }
            noValue = "No Data"
          }
          overrides = []
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
          text = {}
        }
      },
      
      # Movies
      {
        type = "stat"
        title = "Movies"
        gridPos = { h = 4, w = 5, x = 4, y = 1 }
        id = 3
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(radarr_movie_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # TV Shows
      {
        type = "stat"
        title = "TV Shows"
        gridPos = { h = 4, w = 5, x = 9, y = 1 }
        id = 4
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(sonarr_series_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # TV Episodes
      {
        type = "stat"
        title = "TV Episodes"
        gridPos = { h = 4, w = 5, x = 14, y = 1 }
        id = 5
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(sonarr_episode_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Music Artists
      {
        type = "stat"
        title = "Music Artists"
        gridPos = { h = 4, w = 5, x = 19, y = 1 }
        id = 6
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(lidarr_artists_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Service Health Table 
      {
        type = "table"
        title = "Service Health Details"
        gridPos = { h = 8, w = 24, x = 0, y = 5 }
        id = 50
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            # Health indicator - 1 if CPU usage exists, 0 if not
            expr = "(pod:cpu_usage_millicores{namespace=\"default\", workload=~\"jellyfin|jellyseerr|lidarr|overseerr|plex|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli\"} > bool 0)"
            refId = "Health"
            format = "table"
            instant = true
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            # CPU usage from recording rule
            expr = "pod:cpu_usage_millicores{namespace=\"default\", workload=~\"jellyfin|jellyseerr|lidarr|overseerr|plex|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli\"}"
            refId = "CPUUsage"
            format = "table"
            instant = true
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            # CPU percentage against request
            expr = "pod:cpu_request_percent{namespace=\"default\", workload=~\"jellyfin|jellyseerr|lidarr|overseerr|plex|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli\"}"
            refId = "CPURequestPercent"
            format = "table"
            instant = true
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            # CPU percentage against limit - with fallback to NaN for missing values
            expr = "pod:cpu_limit_percent{namespace=\"default\", workload=~\"jellyfin|jellyseerr|lidarr|overseerr|plex|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli\"} or (pod:cpu_usage_millicores{namespace=\"default\", workload=~\"jellyfin|jellyseerr|lidarr|overseerr|plex|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli\"} * 0 + NaN)"
            refId = "CPULimitPercent"
            format = "table"
            instant = true
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            # Memory usage from recording rule
            expr = "pod:memory_usage_mb{namespace=\"default\", workload=~\"jellyfin|jellyseerr|lidarr|overseerr|plex|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli\"}"
            refId = "MemUsage"
            format = "table"
            instant = true
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            # Memory percentage against request
            expr = "pod:memory_request_percent{namespace=\"default\", workload=~\"jellyfin|jellyseerr|lidarr|overseerr|plex|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli\"}"
            refId = "MemRequestPercent"
            format = "table"
            instant = true
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            # Memory percentage against limit - with fallback to NaN for missing values
            expr = "pod:memory_limit_percent{namespace=\"default\", workload=~\"jellyfin|jellyseerr|lidarr|overseerr|plex|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli\"} or (pod:memory_usage_mb{namespace=\"default\", workload=~\"jellyfin|jellyseerr|lidarr|overseerr|plex|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli\"} * 0 + NaN)"
            refId = "MemLimitPercent"
            format = "table"
            instant = true
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "label_replace(sum by (pod) (rate(container_network_receive_bytes_total{namespace=\"default\", pod=~\"jellyfin.*|jellyseerr.*|lidarr.*|overseerr.*|plex.*|prowlarr.*|radarr.*|readarr.*|sabnzbd.*|sonarr.*|tautulli.*\"}[5m])) * 8 / 1000000, \"workload\", \"$1\", \"pod\", \"^([a-z-]+)-[0-9a-z]+-[0-9a-z]+$\")"
            refId = "C"
            format = "table"
            instant = true
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "label_replace(sum by (pod) (rate(container_network_transmit_bytes_total{namespace=\"default\", pod=~\"jellyfin.*|jellyseerr.*|lidarr.*|overseerr.*|plex.*|prowlarr.*|radarr.*|readarr.*|sabnzbd.*|sonarr.*|tautulli.*\"}[5m])) * 8 / 1000000, \"workload\", \"$1\", \"pod\", \"^([a-z-]+)-[0-9a-z]+-[0-9a-z]+$\")"
            refId = "D"
            format = "table"
            instant = true
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            # K6 synthetic monitoring response time (average) - using recording rule for persistence
            # Maps service to workload, uses plex-internal for plex
            expr = <<-EOT
              label_join(
                k6:http_req_duration_seconds:avg{service=~"jellyfin|jellyseerr|lidarr|overseerr|prowlarr|radarr|readarr|sabnzbd|sonarr|tautulli"} * 1000,
                "workload", "", "service"
              ) 
              or 
              label_replace(
                k6:http_req_duration_seconds:avg{service="plex-internal"} * 1000,
                "workload", "plex", "service", ".*"
              )
            EOT
            refId = "ResponseTime"
            format = "table"
            instant = true
          }
        ]
        
        fieldConfig = {
          defaults = {
            custom = {
              align = "auto"
              displayMode = "auto"
              inspect = false
              filterable = false
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "red", value = 80 }
              ]
            }
          }
          overrides = [
            {
              matcher = { id = "byName", options = " " }
              properties = [
                {
                  id = "custom.width"
                  value = 40
                },
                {
                  id = "custom.displayMode"
                  value = "color-background-solid"
                },
                {
                  id = "custom.cellOptions"
                  value = {
                    type = "color-background"
                    mode = "solid"
                  }
                },
                {
                  id = "thresholds"
                  value = {
                    mode = "absolute"
                    steps = [
                      { color = "red", value = null },
                      { color = "green", value = 0.0001 }
                    ]
                  }
                },
                {
                  id = "mappings"
                  value = [
                    {
                      type = "range"
                      options = {
                        from = 0.0001
                        to = 100
                        result = {
                          text = " "
                          index = 0
                        }
                      }
                    },
                    {
                      type = "range"
                      options = {
                        from = 0
                        to = 0.00009
                        result = {
                          text = " "
                          index = 1
                        }
                      }
                    }
                  ]
                },
                {
                  id = "custom.align"
                  value = "center"
                }
              ]
            },
            {
              matcher = { id = "byName", options = "Service" }
              properties = [
                {
                  id = "custom.width"
                  value = 120
                }
              ]
            },
            {
              matcher = { id = "byName", options = "CPU (m)" }
              properties = [
                {
                  id = "custom.width"
                  value = 80
                }
              ]
            },
            {
              matcher = { id = "byName", options = "%CPU/R" }
              properties = [
                {
                  id = "custom.width"
                  value = 80
                }
              ]
            },
            {
              matcher = { id = "byName", options = "%CPU/L" }
              properties = [
                {
                  id = "noValue"
                  value = "N/A"
                },
                {
                  id = "custom.width"
                  value = 80
                },
                {
                  id = "mappings"
                  value = [
                    {
                      type = "special"
                      options = {
                        match = "nan"
                        result = {
                          text = "N/A"
                          color = "text"
                        }
                      }
                    }
                  ]
                }
              ]
            },
            {
              matcher = { id = "byName", options = "MEM (MiB)" }
              properties = [
                {
                  id = "custom.width"
                  value = 90
                }
              ]
            },
            {
              matcher = { id = "byName", options = "%MEM/R" }
              properties = [
                {
                  id = "custom.width"
                  value = 80
                }
              ]
            },
            {
              matcher = { id = "byName", options = "%MEM/L" }
              properties = [
                {
                  id = "noValue"
                  value = "N/A"
                },
                {
                  id = "custom.width"
                  value = 80
                },
                {
                  id = "mappings"
                  value = [
                    {
                      type = "special"
                      options = {
                        match = "nan"
                        result = {
                          text = "N/A"
                          color = "text"
                        }
                      }
                    }
                  ]
                }
              ]
            },
            {
              matcher = { id = "byName", options = "RX" }
              properties = [
                {
                  id = "custom.width"
                  value = 80
                },
                {
                  id = "decimals"
                  value = 1
                },
                {
                  id = "unit"
                  value = "Mbits"
                }
              ]
            },
            {
              matcher = { id = "byName", options = "TX" }
              properties = [
                {
                  id = "custom.width"
                  value = 80
                },
                {
                  id = "decimals"
                  value = 1
                },
                {
                  id = "unit"
                  value = "Mbits"
                }
              ]
            },
            {
              matcher = { id = "byName", options = "RT (ms)" }
              properties = [
                {
                  id = "custom.width"
                  value = 80
                },
                {
                  id = "unit"
                  value = "ms"
                },
                {
                  id = "decimals"
                  value = 0
                },
                {
                  id = "custom.displayMode"
                  value = "color-background-solid"
                },
                {
                  id = "thresholds"
                  value = {
                    mode = "absolute"
                    steps = [
                      { color = "green", value = null },
                      { color = "yellow", value = 500 },
                      { color = "red", value = 1000 }
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
              displayName = "Success Rate"
              desc = false
            }
          ]
        }
        
        transformations = [
          {
            id = "joinByField"
            options = {
              byField = "workload"
              mode = "outer"
            }
          },
          {
            id = "filterFieldsByName"
            options = {
              include = {
                pattern = "workload|Value.*"
              }
            }
          },
          {
            id = "organize"
            options = {
              excludeByName = {}
              renameByName = {
                "workload" = "Service"
                "Value #Health" = " "
                "Value #CPUUsage" = "CPU (m)"
                "Value #CPURequestPercent" = "%CPU/R"
                "Value #CPULimitPercent" = "%CPU/L"
                "Value #MemUsage" = "MEM (MiB)"
                "Value #MemRequestPercent" = "%MEM/R"
                "Value #MemLimitPercent" = "%MEM/L"
                "Value #C" = "RX"
                "Value #D" = "TX"
                "Value #ResponseTime" = "RT (ms)"
              }
              indexByName = {
                "Service" = 0
                " " = 1
                "CPU (m)" = 2
                "%CPU/R" = 3
                "%CPU/L" = 4
                "MEM (MiB)" = 5
                "%MEM/R" = 6
                "%MEM/L" = 7
                "RX" = 8
                "TX" = 9
                "RT (ms)" = 10
              }
            }
          }
        ]
      },
      
      # Row: Plex Performance
      {
        type      = "row"
        title     = "Plex Performance"
        gridPos   = { h = 1, w = 24, x = 0, y = 13 }
        id        = 10
        collapsed = false
      },
      
      # Plex Active Streams
      {
        type = "timeseries"
        title = "Plex Active Streams"
        gridPos = { h = 8, w = 12, x = 0, y = 14 }
        id = 11
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sum(tautulli_stream_direct_play) or on() vector(0)"
            refId = "A"
            legendFormat = "Direct Play"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sum(tautulli_stream_direct_stream) or on() vector(0)"
            refId = "B"
            legendFormat = "Direct Stream"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sum(tautulli_stream_count_transcode) or on() vector(0)"
            refId = "C"
            legendFormat = "Transcoding"
          }
        ]
        
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "stepAfter"
              lineWidth = 2
              fillOpacity = 30
              gradientMode = "opacity"
              spanNulls = true
              showPoints = "never"
              pointSize = 5
              stacking = { mode = "normal", group = "A" }
              axisPlacement = "auto"
              axisLabel = ""
              axisColorMode = "text"
              scaleDistribution = { type = "linear" }
              axisCenteredZero = false
              hideFrom = { tooltip = false, viz = false, legend = false }
              thresholdsStyle = { mode = "off" }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
          overrides = [
            {
              matcher = { id = "byName", options = "Direct Play" }
              properties = [
                {
                  id = "color"
                  value = { mode = "fixed", fixedColor = "green" }
                }
              ]
            },
            {
              matcher = { id = "byName", options = "Direct Stream" }
              properties = [
                {
                  id = "color"
                  value = { mode = "fixed", fixedColor = "yellow" }
                }
              ]
            },
            {
              matcher = { id = "byName", options = "Transcoding" }
              properties = [
                {
                  id = "color"
                  value = { mode = "fixed", fixedColor = "orange" }
                }
              ]
            }
          ]
        }
        
        options = {
          tooltip = {
            mode = "multi"
            sort = "none"
          }
          legend = {
            showLegend = true
            displayMode = "list"
            placement = "bottom"
            calcs = []
          }
        }
      },
      
      # Plex Bandwidth Usage
      {
        type = "timeseries"
        title = "Plex Bandwidth Usage"
        gridPos = { h = 8, w = 12, x = 12, y = 14 }
        id = 12
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "(sum(tautulli_bandwidth_lan) * 8 / 1000000) or on() vector(0)"
            refId = "A"
            legendFormat = "LAN Bandwidth"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "(sum(tautulli_bandwidth_wan) * 8 / 1000000) or on() vector(0)"
            refId = "B"
            legendFormat = "WAN Bandwidth"
          }
        ]
        
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "stepAfter"
              lineWidth = 2
              fillOpacity = 10
              gradientMode = "opacity"
              spanNulls = true
              showPoints = "never"
              pointSize = 5
              stacking = { mode = "none", group = "A" }
              axisPlacement = "auto"
              axisLabel = ""
              axisColorMode = "text"
              scaleDistribution = { type = "linear" }
              axisCenteredZero = false
              hideFrom = { tooltip = false, viz = false, legend = false }
              thresholdsStyle = { mode = "off" }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 50 },
                { color = "red", value = 100 }
              ]
            }
            unit = "Mbits"
          }
        }
        
        options = {
          tooltip = {
            mode = "multi"
            sort = "none"
          }
          legend = {
            showLegend = true
            displayMode = "list"
            placement = "bottom"
            calcs = []
          }
        }
      },
      
      # Row: Radarr
      {
        type      = "text"
        title     = "Movie Library"
        gridPos   = { h = 1, w = 24, x = 0, y = 22 }
        id        = 20
        transparent = true
        
        options = {
          mode = "markdown"
          content = ""
        }
      },
      
      # Radarr Logo
      {
        type = "text"
        title = ""
        gridPos = { h = 4, w = 3, x = 0, y = 23 }
        id = 30
        transparent = true
        
        options = {
          mode = "html"
          content = <<-EOT
            <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100%;">
              <a href="https://radarr.56kbps.io" target="_blank" style="text-decoration: none;">
                <img src="https://raw.githubusercontent.com/Radarr/Radarr/develop/Logo/128.png" style="width: 64px; height: 64px; margin-bottom: 8px;">
                <div style="text-align: center; color: #FFC230; font-weight: bold; font-size: 16px;">Radarr</div>
              </a>
            </div>
          EOT
        }
      },
      
      # Radarr Queue
      {
        type = "stat"
        title = "Queue"
        gridPos = { h = 4, w = 4, x = 3, y = 23 }
        id = 21
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(radarr_queue_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 5 },
                { color = "red", value = 10 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Movies Wanted
      {
        type = "stat"
        title = "Movies Wanted"
        gridPos = { h = 4, w = 4, x = 7, y = 23 }
        id = 22
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(radarr_movie_wanted_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 10 },
                { color = "orange", value = 25 },
                { color = "red", value = 50 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Movies Missing
      {
        type = "stat"
        title = "Movies Missing"
        gridPos = { h = 4, w = 5, x = 11, y = 23 }
        id = 23
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(radarr_movie_missing_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 5 },
                { color = "orange", value = 15 },
                { color = "red", value = 30 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Total File Size
      {
        type = "stat"
        title = "Total Size"
        gridPos = { h = 4, w = 4, x = 16, y = 23 }
        id = 24
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(radarr_movie_filesize_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "decbytes"
            decimals = 2
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Health Issues
      {
        type = "stat"
        title = "Issues"
        gridPos = { h = 4, w = 4, x = 20, y = 23 }
        id = 25
        description = "Click to view issues in Radarr"
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(radarr_system_health_issues[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 1 },
                { color = "red", value = 3 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
            links = [
              {
                title = "View in Radarr"
                url = "https://radarr.56kbps.io/system/status"
                targetBlank = true
              }
            ]
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Row: TV Library (Sonarr)
      {
        type      = "text"
        title     = "TV Library"
        gridPos   = { h = 1, w = 24, x = 0, y = 27 }
        id        = 40
        transparent = true
        
        options = {
          mode = "markdown"
          content = ""
        }
      },
      
      # Sonarr Logo
      {
        type = "text"
        title = ""
        gridPos = { h = 4, w = 3, x = 0, y = 28 }
        id = 41
        transparent = true
        
        options = {
          mode = "html"
          content = <<-EOT
            <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100%;">
              <a href="https://sonarr.56kbps.io" target="_blank" style="text-decoration: none;">
                <img src="https://raw.githubusercontent.com/Sonarr/Sonarr/develop/Logo/128.png" style="width: 64px; height: 64px; margin-bottom: 8px;">
                <div style="text-align: center; color: #35C5F4; font-weight: bold; font-size: 16px;">Sonarr</div>
              </a>
            </div>
          EOT
        }
      },
      
      # Sonarr Queue
      {
        type = "stat"
        title = "Queue"
        gridPos = { h = 4, w = 4, x = 3, y = 28 }
        id = 42
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(sonarr_queue_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 5 },
                { color = "red", value = 10 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Series Monitored
      {
        type = "stat"
        title = "Series Monitored"
        gridPos = { h = 4, w = 4, x = 7, y = 28 }
        id = 43
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(sonarr_series_monitored_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Episodes Missing
      {
        type = "stat"
        title = "Episodes Missing"
        gridPos = { h = 4, w = 5, x = 11, y = 28 }
        id = 44
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(sonarr_episode_missing_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 10 },
                { color = "orange", value = 50 },
                { color = "red", value = 100 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Total File Size
      {
        type = "stat"
        title = "Total Size"
        gridPos = { h = 4, w = 4, x = 16, y = 28 }
        id = 45
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(sonarr_series_filesize_bytes[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "decbytes"
            decimals = 2
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Health Issues
      {
        type = "stat"
        title = "Issues"
        gridPos = { h = 4, w = 4, x = 20, y = 28 }
        id = 46
        description = "Click to view issues in Sonarr"
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(sonarr_system_health_issues[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 1 },
                { color = "red", value = 3 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
            links = [
              {
                title = "View in Sonarr"
                url = "https://sonarr.56kbps.io/system/status"
                targetBlank = true
              }
            ]
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Row: Music Library
      {
        type      = "text"
        title     = "Music Library"
        gridPos   = { h = 1, w = 24, x = 0, y = 32 }
        id        = 50
        transparent = true
        
        options = {
          mode = "markdown"
          content = ""
        }
      },
      
      # Lidarr Logo
      {
        type = "text"
        title = ""
        gridPos = { h = 4, w = 3, x = 0, y = 33 }
        id = 51
        transparent = true
        
        options = {
          mode = "html"
          content = <<-EOT
            <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100%;">
              <a href="https://lidarr.56kbps.io" target="_blank" style="text-decoration: none;">
                <img src="https://raw.githubusercontent.com/Lidarr/Lidarr/develop/Logo/128.png" style="width: 64px; height: 64px; margin-bottom: 8px;">
                <div style="text-align: center; color: #28A745; font-weight: bold; font-size: 16px;">Lidarr</div>
              </a>
            </div>
          EOT
        }
      },
      
      # Lidarr Queue
      {
        type = "stat"
        title = "Queue"
        gridPos = { h = 4, w = 4, x = 3, y = 33 }
        id = 52
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(lidarr_queue_records_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 1 },
                { color = "red", value = 5 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Lidarr Artists Monitored
      {
        type = "stat"
        title = "Artists Monitored"
        gridPos = { h = 4, w = 4, x = 7, y = 33 }
        id = 53
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(lidarr_artist_monitored[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Lidarr Albums Missing
      {
        type = "stat"
        title = "Albums Missing"
        gridPos = { h = 4, w = 5, x = 11, y = 33 }
        id = 54
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(lidarr_album_missing[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 10 },
                { color = "red", value = 50 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Lidarr Total Size
      {
        type = "stat"
        title = "Total Size"
        gridPos = { h = 4, w = 4, x = 16, y = 33 }
        id = 55
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(lidarr_artist_filesize_bytes[10m])) / 1024 / 1024 / 1024"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "decgbytes"
            decimals = 1
            noValue = "0.0 GB"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Lidarr Issues
      {
        type = "stat"
        title = "Issues"
        gridPos = { h = 4, w = 4, x = 20, y = 33 }
        id = 56
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(lidarr_system_health_issues[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 1 },
                { color = "red", value = 3 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
            links = [
              {
                title = "View in Lidarr"
                url = "https://lidarr.56kbps.io/system/status"
                targetBlank = true
              }
            ]
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Row: Book Library
      {
        type      = "text"
        title     = "Book Library"
        gridPos   = { h = 1, w = 24, x = 0, y = 37 }
        id        = 60
        transparent = true
        
        options = {
          mode = "markdown"
          content = ""
        }
      },
      
      # Readarr Logo
      {
        type = "text"
        title = ""
        gridPos = { h = 4, w = 3, x = 0, y = 38 }
        id = 61
        transparent = true
        
        options = {
          mode = "html"
          content = <<-EOT
            <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100%;">
              <a href="https://readarr.56kbps.io" target="_blank" style="text-decoration: none;">
                <img src="https://raw.githubusercontent.com/Readarr/Readarr/develop/Logo/128.png" style="width: 64px; height: 64px; margin-bottom: 8px;">
                <div style="text-align: center; color: #8E2DE2; font-weight: bold; font-size: 16px;">Readarr</div>
              </a>
            </div>
          EOT
        }
      },
      
      # Readarr Queue
      {
        type = "stat"
        title = "Queue"
        gridPos = { h = 4, w = 4, x = 3, y = 38 }
        id = 62
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(readarr_queue_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 1 },
                { color = "red", value = 5 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Readarr Authors Monitored
      {
        type = "stat"
        title = "Authors Monitored"
        gridPos = { h = 4, w = 4, x = 7, y = 38 }
        id = 63
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(readarr_author_monitored[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Readarr Books Missing
      {
        type = "stat"
        title = "Books Missing"
        gridPos = { h = 4, w = 5, x = 11, y = 38 }
        id = 64
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(readarr_book_missing[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 10 },
                { color = "red", value = 50 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Readarr Total Size
      {
        type = "stat"
        title = "Total Size"
        gridPos = { h = 4, w = 4, x = 16, y = 38 }
        id = 65
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(readarr_author_filesize_bytes[10m])) / 1024 / 1024 / 1024"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "decgbytes"
            decimals = 1
            noValue = "0.0 GB"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Readarr Issues
      {
        type = "stat"
        title = "Issues"
        gridPos = { h = 4, w = 4, x = 20, y = 38 }
        id = 66
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(readarr_system_health_issues[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 1 },
                { color = "red", value = 3 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
            links = [
              {
                title = "View in Readarr"
                url = "https://readarr.56kbps.io/system/status"
                targetBlank = true
              }
            ]
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Row: Indexer Management
      {
        type      = "text"
        title     = "Indexer Management"
        gridPos   = { h = 1, w = 24, x = 0, y = 42 }
        id        = 70
        transparent = true
        
        options = {
          mode = "markdown"
          content = ""
        }
      },
      
      # Prowlarr Logo
      {
        type = "text"
        title = ""
        gridPos = { h = 4, w = 3, x = 0, y = 43 }
        id = 71
        transparent = true
        
        options = {
          mode = "html"
          content = <<-EOT
            <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100%;">
              <a href="https://prowlarr.56kbps.io" target="_blank" style="text-decoration: none;">
                <img src="https://raw.githubusercontent.com/Prowlarr/Prowlarr/develop/Logo/128.png" style="width: 64px; height: 64px; margin-bottom: 8px;">
                <div style="text-align: center; color: #4A90E2; font-weight: bold; font-size: 16px;">Prowlarr</div>
              </a>
            </div>
          EOT
        }
      },
      
      # Prowlarr Indexers Enabled
      {
        type = "stat"
        title = "Indexers Enabled"
        gridPos = { h = 4, w = 5, x = 3, y = 43 }
        id = 72
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(prowlarr_indexer_enabled_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "red", value = null },
                { color = "yellow", value = 1 },
                { color = "green", value = 5 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Prowlarr Total Indexers
      {
        type = "stat"
        title = "Total Indexers"
        gridPos = { h = 4, w = 5, x = 8, y = 43 }
        id = 73
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(prowlarr_indexer_total[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Prowlarr Issues
      {
        type = "stat"
        title = "Issues"
        gridPos = { h = 4, w = 5, x = 13, y = 43 }
        id = 74
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(prowlarr_system_health_issues[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 1 },
                { color = "red", value = 3 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "0"
            links = [
              {
                title = "View in Prowlarr"
                url = "https://prowlarr.56kbps.io/system/status"
                targetBlank = true
              }
            ]
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Prowlarr System Status
      {
        type = "stat"
        title = "System Status"
        gridPos = { h = 4, w = 6, x = 18, y = 43 }
        id = 75
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "max(last_over_time(prowlarr_system_status[10m]))"
            refId = "A"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = [
              {
                type = "value"
                value = "0"
                options = {
                  text = "OK"
                  color = "green"
                }
              },
              {
                type = "value"
                value = "1"
                options = {
                  text = "Error"
                  color = "red"
                }
              }
            ]
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "red", value = 1 }
              ]
            }
            unit = "none"
            decimals = 0
            noValue = "Unknown"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Row: Download Activity
      {
        type      = "row"
        title     = "Download Activity"
        gridPos   = { h = 1, w = 24, x = 0, y = 47 }
        id        = 30
        collapsed = false
      },
      
      # Download Queue Timeline
      {
        type = "timeseries"
        title = "Download Queue Activity"
        gridPos = { h = 8, w = 12, x = 0, y = 48 }
        id = 31
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sonarr_queue_total"
            refId = "A"
            legendFormat = "Sonarr"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "radarr_queue_total"
            refId = "B"
            legendFormat = "Radarr"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "lidarr_queue_records_total"
            refId = "C"
            legendFormat = "Lidarr"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "readarr_queue_total"
            refId = "D"
            legendFormat = "Readarr"
          }
        ]
        
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "smooth"
              lineWidth = 2
              fillOpacity = 10
              gradientMode = "opacity"
              spanNulls = false
              showPoints = "never"
              pointSize = 5
              stacking = { mode = "none", group = "A" }
              axisPlacement = "auto"
              axisLabel = ""
              axisColorMode = "text"
              scaleDistribution = { type = "linear" }
              axisCenteredZero = false
              hideFrom = { tooltip = false, viz = false, legend = false }
              thresholdsStyle = { mode = "off" }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "none"
            decimals = 0
          }
        }
        
        options = {
          tooltip = {
            mode = "multi"
            sort = "none"
          }
          legend = {
            showLegend = true
            displayMode = "list"
            placement = "bottom"
            calcs = ["mean", "max"]
          }
        }
      },
      
      # SABnzbd Activity
      {
        type = "timeseries"
        title = "SABnzbd Download Rate"
        gridPos = { h = 8, w = 12, x = 12, y = 48 }
        id = 32
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sabnzbd_download_rate / 1024"
            refId = "A"
            legendFormat = "Download Rate"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sabnzbd_queue_size_mb"
            refId = "B"
            legendFormat = "Queue Size (MB)"
          }
        ]
        
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "smooth"
              lineWidth = 2
              fillOpacity = 10
              gradientMode = "opacity"
              spanNulls = false
              showPoints = "never"
              pointSize = 5
              stacking = { mode = "none", group = "A" }
              axisPlacement = "auto"
              axisLabel = ""
              axisColorMode = "text"
              scaleDistribution = { type = "linear" }
              axisCenteredZero = false
              hideFrom = { tooltip = false, viz = false, legend = false }
              thresholdsStyle = { mode = "off" }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "MBs"
          }
          overrides = [
            {
              matcher = { id = "byName", options = "Queue Size (MB)" }
              properties = [
                {
                  id = "unit"
                  value = { mode = "absolute", fixedUnit = "decmbytes" }
                },
                {
                  id = "custom.axisPlacement"
                  value = "right"
                }
              ]
            }
          ]
        }
        
        options = {
          tooltip = {
            mode = "multi"
            sort = "none"
          }
          legend = {
            showLegend = true
            displayMode = "list"
            placement = "bottom"
            calcs = ["mean", "max"]
          }
        }
      },
      
      # Row: System Resources
      {
        type      = "row"
        title     = "System Resources"
        gridPos   = { h = 1, w = 24, x = 0, y = 56 }
        id        = 40
        collapsed = false
      },
      
      # CPU Usage by Service
      {
        type = "timeseries"
        title = "CPU Usage by Service"
        gridPos = { h = 8, w = 12, x = 0, y = 57 }
        id = 41
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sum(rate(container_cpu_usage_seconds_total{namespace=\"media\", container!=\"\", container!=\"POD\"}[5m])) by (container) * 100"
            refId = "A"
            legendFormat = "{{ container }}"
          }
        ]
        
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "smooth"
              lineWidth = 2
              fillOpacity = 10
              gradientMode = "opacity"
              spanNulls = false
              showPoints = "never"
              pointSize = 5
              stacking = { mode = "none", group = "A" }
              axisPlacement = "auto"
              axisLabel = ""
              axisColorMode = "text"
              scaleDistribution = { type = "linear" }
              axisCenteredZero = false
              hideFrom = { tooltip = false, viz = false, legend = false }
              thresholdsStyle = { mode = "off" }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "yellow", value = 50 },
                { color = "red", value = 80 }
              ]
            }
            unit = "percent"
            min = 0
            max = 100
          }
        }
        
        options = {
          tooltip = {
            mode = "multi"
            sort = "desc"
          }
          legend = {
            showLegend = true
            displayMode = "table"
            placement = "right"
            calcs = ["mean", "max"]
          }
        }
      },
      
      # Memory Usage by Service
      {
        type = "timeseries"
        title = "Memory Usage by Service"
        gridPos = { h = 8, w = 12, x = 12, y = 57 }
        id = 42
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sum(container_memory_working_set_bytes{namespace=\"media\", container!=\"\", container!=\"POD\"}) by (container) / 1024 / 1024 / 1024"
            refId = "A"
            legendFormat = "{{ container }}"
          }
        ]
        
        fieldConfig = {
          defaults = {
            custom = {
              drawStyle = "line"
              lineInterpolation = "smooth"
              lineWidth = 2
              fillOpacity = 10
              gradientMode = "opacity"
              spanNulls = false
              showPoints = "never"
              pointSize = 5
              stacking = { mode = "normal", group = "A" }
              axisPlacement = "auto"
              axisLabel = ""
              axisColorMode = "text"
              scaleDistribution = { type = "linear" }
              axisCenteredZero = false
              hideFrom = { tooltip = false, viz = false, legend = false }
              thresholdsStyle = { mode = "off" }
            }
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null }
              ]
            }
            unit = "decgbytes"
          }
        }
        
        options = {
          tooltip = {
            mode = "multi"
            sort = "desc"
          }
          legend = {
            showLegend = true
            displayMode = "table"
            placement = "right"
            calcs = ["mean", "max"]
          }
        }
      }
    ]
  })
  
  folder = data.grafana_folder.applications.id
}