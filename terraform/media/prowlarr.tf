provider "prowlarr" {
  url     = module.secrets.items["prowlarr"].PROWLARR_URL
  api_key = module.secrets.items["prowlarr"].PROWLARR_API_KEY
}

resource "prowlarr_host" "stonehedges" {
  launch_browser = true
  port = 80
  url_base = ""
  bind_address = "*"
  application_url = ""
  instance_name = "Prowlarr"
  proxy = {
    enabled = false
    username = ""
    hostname = ""
    port = 8080
    type = "http"
    bypass_local_addresses = true
    byass_filter = ""
  }
  ssl = {
    enabled = false
    certificate_validation = "enabled"
    cert_path = ""
    cert_password = ""
    port = 6969
  }
  authentication = {
    method = "external"
    password = ""
    username = ""
  }
  backup = {
    folder = "backups"
    interval = 7
    retention = 28
  }
  logging = {
    log_level = "info"
    log_size_limit = 1
    analytics_enabled = false
    console_log_level = "info"
  }
  update = {
    mechanism = "docker"
    branch = "develop"
    update_automatically = false
    script_path = ""
  }
}

resource "prowlarr_application_radarr" "radarr" {
  name = "Radarr"
  sync_level = "fullSync"
  base_url = "http://radarr.default.svc.cluster.local"
  prowlarr_url = "http://prowlarr.default.svc.cluster.local"
  api_key = module.secrets.items["radarr"].RADARR_API_KEY
  sync_categories = [2000]
}

resource "prowlarr_application_lidarr" "lidarr" {
  name = "Lidarr"
  sync_level = "fullSync"
  base_url = "http://lidarr.default.svc.cluster.local"
  prowlarr_url = "http://prowlarr.default.svc.cluster.local"
  api_key = module.secrets.items["lidarr"].LIDARR_API_KEY
  sync_categories = [3000, 3010, 3020, 3040, 3050, 3060]
}

resource "prowlarr_application_sonarr" "sonarr" {
  name = "Sonarr"
  sync_level = "fullSync"
  base_url = "http://sonarr.default.svc.cluster.local"
  prowlarr_url = "http://prowlarr.default.svc.cluster.local"
  api_key = module.secrets.items["sonarr"].SONARR_API_KEY
  sync_categories = [5000]
}

resource "prowlarr_application_readarr" "readarr" {
  name = "Readarr"
  sync_level = "fullSync"
  base_url = "http://readarr.default.svc.cluster.local"
  prowlarr_url = "http://prowlarr.default.svc.cluster.local"
  api_key = module.secrets.items["readarr"].READARR_API_KEY
  sync_categories = [3030, 7000]
}
