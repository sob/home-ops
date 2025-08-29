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
          query      = "label_values(up{job=~\".*arr.*|plex.*|jellyfin.*|sabnzbd.*|tautulli.*\"}, job)"
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
        title = "Service Availability"
        gridPos = { h = 4, w = 6, x = 0, y = 1 }
        id = 2
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "count(up{job=~\"$service\"} == 1)"
            refId = "A"
            legendFormat = "Up"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "count(up{job=~\"$service\"} == 0)"
            refId = "B"
            legendFormat = "Down"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "green", value = null },
                { color = "red", value = 1 }
              ]
            }
            unit = "short"
            color = { mode = "thresholds" }
          }
          overrides = [
            {
              matcher = { id = "byName", options = "Down" }
              properties = [
                {
                  id = "color"
                  value = { mode = "fixed", fixedColor = "red" }
                }
              ]
            }
          ]
        }
        
        options = {
          textMode = "value_and_name"
          graphMode = "none"
          orientation = "horizontal"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Total API Requests
      {
        type = "stat"
        title = "Total API Requests (24h)"
        gridPos = { h = 4, w = 6, x = 6, y = 1 }
        id = 3
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sum(increase(traefik_service_requests_total{service=~\".*plex.*|.*jellyfin.*|.*sonarr.*|.*radarr.*|.*prowlarr.*|.*lidarr.*|.*readarr.*|.*sabnzbd.*\"}[24h]))"
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
            unit = "short"
            decimals = 0
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "area"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Average Response Time
      {
        type = "stat"
        title = "Avg Response Time"
        gridPos = { h = 4, w = 6, x = 12, y = 1 }
        id = 4
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "avg(rate(traefik_service_request_duration_seconds_sum{service=~\".*plex.*|.*jellyfin.*|.*sonarr.*|.*radarr.*|.*prowlarr.*|.*lidarr.*|.*readarr.*|.*sabnzbd.*\"}[5m]) / rate(traefik_service_request_duration_seconds_count{service=~\".*plex.*|.*jellyfin.*|.*sonarr.*|.*radarr.*|.*prowlarr.*|.*lidarr.*|.*readarr.*|.*sabnzbd.*\"}[5m])) * 1000"
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
                { color = "yellow", value = 500 },
                { color = "red", value = 1000 }
              ]
            }
            unit = "ms"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "area"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Error Rate
      {
        type = "stat"
        title = "Error Rate (5xx)"
        gridPos = { h = 4, w = 6, x = 18, y = 1 }
        id = 5
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sum(rate(traefik_service_requests_total{service=~\".*plex.*|.*jellyfin.*|.*sonarr.*|.*radarr.*|.*prowlarr.*|.*lidarr.*|.*readarr.*|.*sabnzbd.*\", code=~\"5..\"}[5m])) / sum(rate(traefik_service_requests_total{service=~\".*plex.*|.*jellyfin.*|.*sonarr.*|.*radarr.*|.*prowlarr.*|.*lidarr.*|.*readarr.*|.*sabnzbd.*\"}[5m])) * 100"
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
            unit = "percent"
            decimals = 2
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "area"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Row: Plex Performance
      {
        type      = "row"
        title     = "Plex Performance"
        gridPos   = { h = 1, w = 24, x = 0, y = 5 }
        id        = 10
        collapsed = false
      },
      
      # Plex Active Streams
      {
        type = "timeseries"
        title = "Plex Active Streams"
        gridPos = { h = 8, w = 12, x = 0, y = 6 }
        id = 11
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "tautulli_stream_count"
            refId = "A"
            legendFormat = "Total Streams"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "tautulli_transcode_count"
            refId = "B"
            legendFormat = "Transcoding"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "tautulli_direct_play_count"
            refId = "C"
            legendFormat = "Direct Play"
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
            unit = "short"
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
            calcs = []
          }
        }
      },
      
      # Plex Bandwidth Usage
      {
        type = "timeseries"
        title = "Plex Bandwidth Usage"
        gridPos = { h = 8, w = 12, x = 12, y = 6 }
        id = 12
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "tautulli_total_bandwidth * 8 / 1000000"
            refId = "A"
            legendFormat = "Total Bandwidth"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "tautulli_lan_bandwidth * 8 / 1000000"
            refId = "B"
            legendFormat = "LAN Bandwidth"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "tautulli_wan_bandwidth * 8 / 1000000"
            refId = "C"
            legendFormat = "WAN Bandwidth"
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
            calcs = ["mean", "max"]
          }
        }
      },
      
      # Row: *arr Stack Performance
      {
        type      = "row"
        title     = "*arr Stack Performance"
        gridPos   = { h = 1, w = 24, x = 0, y = 14 }
        id        = 20
        collapsed = false
      },
      
      # Sonarr Queue
      {
        type = "stat"
        title = "Sonarr Queue"
        gridPos = { h = 4, w = 4, x = 0, y = 15 }
        id = 21
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sonarr_queue_total"
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
                { color = "red", value = 25 }
              ]
            }
            unit = "short"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "area"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Radarr Queue
      {
        type = "stat"
        title = "Radarr Queue"
        gridPos = { h = 4, w = 4, x = 4, y = 15 }
        id = 22
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "radarr_queue_total"
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
                { color = "red", value = 25 }
              ]
            }
            unit = "short"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "area"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # SABnzbd Speed
      {
        type = "gauge"
        title = "SABnzbd Download Speed"
        gridPos = { h = 4, w = 4, x = 8, y = 15 }
        id = 23
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sabnzbd_download_rate / 1024"
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
                { color = "yellow", value = 50 },
                { color = "red", value = 100 }
              ]
            }
            unit = "MBs"
            min = 0
            max = 125
          }
        }
        
        options = {
          orientation = "auto"
          showThresholdLabels = false
          showThresholdMarkers = true
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["lastNotNull"]
          }
        }
      },
      
      # Prowlarr Indexers
      {
        type = "stat"
        title = "Prowlarr Indexers"
        gridPos = { h = 4, w = 4, x = 12, y = 15 }
        id = 24
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "prowlarr_indexer_status == 1"
            refId = "A"
            legendFormat = "{{ indexer }}"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "red", value = null },
                { color = "green", value = 1 }
              ]
            }
            unit = "short"
          }
        }
        
        options = {
          textMode = "value"
          graphMode = "none"
          orientation = "auto"
          reduceOptions = {
            values = false
            fields = ""
            calcs = ["count"]
          }
        }
      },
      
      # Library Sizes
      {
        type = "bargauge"
        title = "Library Sizes"
        gridPos = { h = 4, w = 8, x = 16, y = 15 }
        id = 25
        
        targets = [
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sonarr_series_total"
            refId = "A"
            legendFormat = "TV Shows"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "sonarr_episode_total"
            refId = "B"
            legendFormat = "Episodes"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "radarr_movie_total"
            refId = "C"
            legendFormat = "Movies"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "lidarr_artist_count"
            refId = "D"
            legendFormat = "Artists"
          },
          {
            datasource = { type = "prometheus", uid = "$prometheus" }
            expr = "readarr_book_count"
            refId = "E"
            legendFormat = "Books"
          }
        ]
        
        fieldConfig = {
          defaults = {
            mappings = []
            thresholds = {
              mode = "absolute"
              steps = [
                { color = "blue", value = null }
              ]
            }
            unit = "short"
          }
        }
        
        options = {
          displayMode = "gradient"
          orientation = "horizontal"
          showUnfilled = true
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
        gridPos   = { h = 1, w = 24, x = 0, y = 19 }
        id        = 30
        collapsed = false
      },
      
      # Download Queue Timeline
      {
        type = "timeseries"
        title = "Download Queue Activity"
        gridPos = { h = 8, w = 12, x = 0, y = 20 }
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
            unit = "short"
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
        gridPos = { h = 8, w = 12, x = 12, y = 20 }
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
        gridPos   = { h = 1, w = 24, x = 0, y = 28 }
        id        = 40
        collapsed = false
      },
      
      # CPU Usage by Service
      {
        type = "timeseries"
        title = "CPU Usage by Service"
        gridPos = { h = 8, w = 12, x = 0, y = 29 }
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
        gridPos = { h = 8, w = 12, x = 12, y = 29 }
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