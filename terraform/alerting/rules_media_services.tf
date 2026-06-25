resource "grafana_rule_group" "media_apps" {
  name             = "media-apps"
  folder_uid       = grafana_folder.applications.uid
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
    no_data_state = "OK"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "min(up{job=\"plex\",namespace=\"default\"}) < 1"
        refId = "A"
        instant = true      })
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
      severity = "critical"
      service  = "jellyfin"
      category = "media"
    }
    for       = "5m"
    no_data_state = "OK"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "min(up{job=\"jellyfin\",namespace=\"default\"}) < 1"
        refId = "A"
        instant = true      })
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
    no_data_state = "OK"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 300
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "(min(up{job=\"overseerr\",namespace=\"default\"}) < 1) or (min(up{job=\"overseerr-exporter\",namespace=\"observability\"}) < 1)"
        refId = "A"
        instant = true      })
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
    no_data_state = "OK"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "(min(up{job=\"sabnzbd\",namespace=\"default\"}) < 1) or (min(up{job=\"sabnzbd-exporter\",namespace=\"observability\"}) < 1)"
        refId = "A"
        instant = true      })
    }
  }
}

resource "grafana_rule_group" "arr_stack" {
  name             = "arr-stack"
  folder_uid       = grafana_folder.applications.uid
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
    no_data_state = "OK"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "(min(up{job=\"sonarr\",namespace=\"default\"}) < 1) or (min(up{job=\"sonarr-exporter\",namespace=\"observability\"}) < 1)"
        refId = "A"
        instant = true      })
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
    no_data_state = "OK"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "(min(up{job=\"radarr\",namespace=\"default\"}) < 1) or (min(up{job=\"radarr-exporter\",namespace=\"observability\"}) < 1)"
        refId = "A"
        instant = true      })
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
    no_data_state = "OK"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 600
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "(min(up{job=\"prowlarr\",namespace=\"default\"}) < 1) or (min(up{job=\"prowlarr-exporter\",namespace=\"observability\"}) < 1)"
        refId = "A"
        instant = true      })
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
    no_data_state = "OK"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "(min(up{job=\"bazarr\",namespace=\"default\"}) < 1) or (min(up{job=\"bazarr-exporter\",namespace=\"observability\"}) < 1)"
        refId = "A"
        instant = true      })
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
    no_data_state = "OK"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "(min(up{job=\"lidarr\",namespace=\"default\"}) < 1) or (min(up{job=\"lidarr-exporter\",namespace=\"observability\"}) < 1)"
        refId = "A"
        instant = true      })
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
    no_data_state = "OK"
    condition = "A"

    data {
      ref_id = "A"
      
      relative_time_range {
        from = 900
        to   = 0
      }
      
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr  = "(min(up{job=\"readarr\",namespace=\"default\"}) < 1) or (min(up{job=\"readarr-exporter\",namespace=\"observability\"}) < 1)"
        refId = "A"
        instant = true      })
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
    no_data_state = "OK"
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
        instant = true      })
    }
  }

  # --- Application health (queue / library), via exportarr ---

  # Sonarr's own health checks (indexer down, missing root folder, download client, import failures)
  # excludes the benign "update available" notice
  rule {
    name = "SonarrHealthIssue"
    annotations = {
      summary     = "Sonarr health issue: {{ $labels.message }}"
      description = "Sonarr reported a health check failure ({{ $labels.source }}). See {{ $labels.wikiurl }}"
    }
    labels = {
      severity = "warning"
      service  = "sonarr"
      category = "arr-stack"
    }
    for           = "15m"
    no_data_state = "OK"
    condition     = "A"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr    = "sonarr_system_health_issues{type=~\"warning|error\", message!~\".*update is available.*\"} > 0"
        refId   = "A"
        instant = true })
    }
  }

  # Radarr's own health checks
  rule {
    name = "RadarrHealthIssue"
    annotations = {
      summary     = "Radarr health issue: {{ $labels.message }}"
      description = "Radarr reported a health check failure ({{ $labels.source }}). See {{ $labels.wikiurl }}"
    }
    labels = {
      severity = "warning"
      service  = "radarr"
      category = "arr-stack"
    }
    for           = "15m"
    no_data_state = "OK"
    condition     = "A"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr    = "radarr_system_health_issues{type=~\"warning|error\", message!~\".*update is available.*\"} > 0"
        refId   = "A"
        instant = true })
    }
  }

  # Queue items stuck in a failed/blocked state (excludes normal transient importPending)
  rule {
    name = "SonarrQueueStuck"
    annotations = {
      summary     = "Sonarr has stuck queue items"
      description = "{{ $values.A }} item(s) stuck in a failed/import-blocked state for 2h. Check Sonarr > Activity > Queue."
    }
    labels = {
      severity = "warning"
      service  = "sonarr"
      category = "arr-stack"
    }
    for           = "2h"
    no_data_state = "OK"
    condition     = "A"

    data {
      ref_id = "A"
      relative_time_range {
        from = 7200
        to   = 0
      }
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr    = "sum(sonarr_queue_total{download_status=~\"warning|error\", download_state!=\"importPending\"}) > 0"
        refId   = "A"
        instant = true })
    }
  }

  rule {
    name = "RadarrQueueStuck"
    annotations = {
      summary     = "Radarr has stuck queue items"
      description = "{{ $values.A }} item(s) stuck in a failed/import-blocked state for 2h. Check Radarr > Activity > Queue."
    }
    labels = {
      severity = "warning"
      service  = "radarr"
      category = "arr-stack"
    }
    for           = "2h"
    no_data_state = "OK"
    condition     = "A"

    data {
      ref_id = "A"
      relative_time_range {
        from = 7200
        to   = 0
      }
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr    = "sum(radarr_queue_total{download_status=~\"warning|error\", download_state!=\"importPending\"}) > 0"
        refId   = "A"
        instant = true })
    }
  }

  # Media library storage running low (would block imports) — shared NFS, watched via Radarr's root folder
  rule {
    name = "MediaLibraryStorageLow"
    annotations = {
      summary     = "Media library storage is low"
      description = "Less than 50GB free on the media library root folder. New downloads/imports will start failing."
    }
    labels = {
      severity = "warning"
      service  = "media"
      category = "arr-stack"
    }
    for           = "30m"
    no_data_state = "OK"
    condition     = "A"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = local.prometheus_cloud_uid
      model = jsonencode({
        expr    = "min(radarr_rootfolder_freespace_bytes) < 50000000000"
        refId   = "A"
        instant = true })
    }
  }

  # SQLite "database is locked" storm in a media app (e.g. post-migration/restart
  # contention, or storage-level locking). A clean restart usually clears a transient one.
  rule {
    name = "ArrDatabaseLocked"
    annotations = {
      summary     = "Media app SQLite database-locked errors"
      description = "{{ $labels.app }} logged {{ $values.A }} 'database is locked' errors in 10m. If sustained, restart it (kubectl rollout restart deploy/{{ $labels.app }} -n default); if recurring, investigate storage/SQLite locking."
    }
    labels = {
      severity = "warning"
      service  = "arr-stack"
      category = "arr-stack"
    }
    for           = "5m"
    no_data_state = "OK"
    condition     = "A"

    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = local.loki_metal_uid
      model = jsonencode({
        expr      = "sum by (app) (count_over_time({namespace=\"default\"} |~ \"database is locked\" [10m])) > 20"
        refId     = "A"
        queryType = "instant"
        instant   = true })
    }
  }
}