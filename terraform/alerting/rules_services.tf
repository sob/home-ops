# Service monitoring folder
resource "grafana_folder" "services" {
  title = "Critical Services"
}

# Media services are in rules_media_services.tf
# Infrastructure services are in rules_infrastructure.tf
# Application health metrics

resource "grafana_rule_group" "application_health" {
  name             = "application-health"
  folder_uid       = grafana_folder.services.uid
  interval_seconds = 60

  # Queue backup detection for *arr apps
  rule {
    name = "HighQueueBacklog"
    annotations = {
      summary     = "High download queue backlog"
      description = "{{ $labels.app }} has {{ $value }} items in queue for over 30 minutes"
    }
    labels = {
      severity = "warning"
      category = "application"
    }
    for       = "30m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 1800
        to   = 0
      }
      
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "sonarr_queue_total > 10 or radarr_queue_total > 10"
        refId = "A"
      })
    }
  }

  # Failed downloads
  rule {
    name = "FailedDownloads"
    annotations = {
      summary     = "Multiple failed downloads detected"
      description = "SABnzbd has {{ $value }} failed downloads in the last hour"
    }
    labels = {
      severity = "warning"
      service  = "sabnzbd"
      category = "application"
    }
    for       = "10m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "increase(sabnzbd_article_cache_misses[1h]) > 5"
        refId = "A"
      })
    }
  }

  # Indexer health
  rule {
    name = "IndexersFailing"
    annotations = {
      summary     = "Multiple indexers are failing"
      description = "{{ $value }} indexers are currently failing health checks in Prowlarr"
    }
    labels = {
      severity = "warning"
      service  = "prowlarr"
      category = "application"
    }
    for       = "15m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "prowlarr_indexer_status{status!=\"enabled\"} > 2"
        refId = "A"
      })
    }
  }

  # Plex streams
  rule {
    name = "HighPlexLoad"
    annotations = {
      summary     = "High Plex streaming load"
      description = "Plex has {{ $value }} concurrent streams (threshold: 10)"
    }
    labels = {
      severity = "info"
      service  = "plex"
      category = "application"
    }
    for       = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = var.prometheus_datasource_uid
      model = jsonencode({
        expr  = "tautulli_stream_count > 10"
        refId = "A"
      })
    }
  }
}