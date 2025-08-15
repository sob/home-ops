resource "grafana_rule_group" "media_apps" {
  name             = "media-apps"
  folder_uid       = grafana_folder.services.uid
  interval_seconds = 60

  # Plex - Critical media server
  rule {
    name = "PlexDown"
    annotations = {
      summary     = "Plex media server is down"
      description = "Plex has been unreachable for 5 minutes. Users cannot stream media."
    }
    labels = {
      severity = "critical"
      service  = "plex"
      category = "media"
    }
    for       = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"plex\",namespace=\"default\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Jellyfin - Alternative media server
  rule {
    name = "JellyfinDown"
    annotations = {
      summary     = "Jellyfin media server is down"
      description = "Jellyfin has been unreachable for 5 minutes"
    }
    labels = {
      severity = "warning"
      service  = "jellyfin"
      category = "media"
    }
    for       = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"jellyfin\",namespace=\"default\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Request management
  rule {
    name = "OverseerrDown"
    annotations = {
      summary     = "Overseerr request system is down"
      description = "Overseerr has been unreachable for 5 minutes. Users cannot request media."
    }
    labels = {
      severity = "warning"
      service  = "overseerr"
      category = "media"
    }
    for       = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"overseerr\",namespace=\"default\"} < 1 AND up{job=\"overseerr-exporter\",namespace=\"observability\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Download client
  rule {
    name = "SABnzbdDown"
    annotations = {
      summary     = "SABnzbd download client is down"
      description = "SABnzbd has been unreachable for 10 minutes. Downloads are halted."
    }
    labels = {
      severity = "warning"
      service  = "sabnzbd"
      category = "media"
    }
    for       = "10m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"sabnzbd\",namespace=\"default\"} < 1 AND up{job=\"sabnzbd-exporter\",namespace=\"observability\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }
}

resource "grafana_rule_group" "arr_stack" {
  name             = "arr-stack"
  folder_uid       = grafana_folder.services.uid
  interval_seconds = 60

  # Sonarr - TV management
  rule {
    name = "SonarrDown"
    annotations = {
      summary     = "Sonarr TV manager is down"
      description = "Sonarr has been unreachable for 10 minutes. TV show automation is halted."
    }
    labels = {
      severity = "warning"
      service  = "sonarr"
      category = "arr-stack"
    }
    for       = "10m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"sonarr\",namespace=\"default\"} < 1 AND up{job=\"sonarr-exporter\",namespace=\"observability\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Radarr - Movie management
  rule {
    name = "RadarrDown"
    annotations = {
      summary     = "Radarr movie manager is down"
      description = "Radarr has been unreachable for 10 minutes. Movie automation is halted."
    }
    labels = {
      severity = "warning"
      service  = "radarr"
      category = "arr-stack"
    }
    for       = "10m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"radarr\",namespace=\"default\"} < 1 AND up{job=\"radarr-exporter\",namespace=\"observability\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Prowlarr - Indexer management
  rule {
    name = "ProwlarrDown"
    annotations = {
      summary     = "Prowlarr indexer manager is down"
      description = "Prowlarr has been unreachable for 10 minutes. Indexer searches are failing."
    }
    labels = {
      severity = "warning"
      service  = "prowlarr"
      category = "arr-stack"
    }
    for       = "10m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"prowlarr\",namespace=\"default\"} < 1 AND up{job=\"prowlarr-exporter\",namespace=\"observability\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Bazarr - Subtitle management
  rule {
    name = "BazarrDown"
    annotations = {
      summary     = "Bazarr subtitle manager is down"
      description = "Bazarr has been unreachable for 15 minutes. Subtitle downloads are halted."
    }
    labels = {
      severity = "info"
      service  = "bazarr"
      category = "arr-stack"
    }
    for       = "15m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"bazarr\",namespace=\"default\"} < 1 AND up{job=\"bazarr-exporter\",namespace=\"observability\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Lidarr - Music management
  rule {
    name = "LidarrDown"
    annotations = {
      summary     = "Lidarr music manager is down"
      description = "Lidarr has been unreachable for 15 minutes. Music automation is halted."
    }
    labels = {
      severity = "info"
      service  = "lidarr"
      category = "arr-stack"
    }
    for       = "15m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"lidarr\",namespace=\"default\"} < 1 AND up{job=\"lidarr-exporter\",namespace=\"observability\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Readarr - Book management
  rule {
    name = "ReadarrDown"
    annotations = {
      summary     = "Readarr book manager is down"
      description = "Readarr has been unreachable for 15 minutes. Book automation is halted."
    }
    labels = {
      severity = "info"
      service  = "readarr"
      category = "arr-stack"
    }
    for       = "15m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "up{job=\"readarr\",namespace=\"default\"} < 1 AND up{job=\"readarr-exporter\",namespace=\"observability\"} < 1"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }

  # Multiple arr services down
  rule {
    name = "MultipleArrServicesDown"
    annotations = {
      summary     = "Multiple *arr services are down"
      description = "{{ $value }} *arr services are currently down. Media automation is severely impacted."
    }
    labels = {
      severity = "critical"
      category = "arr-stack"
    }
    for       = "5m"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "count(up{job=~\"(sonarr|radarr|prowlarr|bazarr|lidarr|readarr)\",namespace=\"default\"} < 1) > 2"
        refId = "A"
        instant = true
        intervalMs = 1000
        maxDataPoints = 43200
      })
    }
  }
}