provider "sonarr" {
  url     = module.secrets.items["sonarr"].SONARR_URL
  api_key = module.secrets.items["sonarr"].SONARR_API_KEY
}

resource "sonarr_root_folder" "series" {
  path = "/media/Library/series"
}

resource "sonarr_download_client_sabnzbd" "sabnzbd" {
  enable                     = true
  priority                   = 1
  name                       = "SABnzbd"
  host                       = "sabnzbd.default.svc.cluster.local"
  port                       = "80"
  api_key                    = module.secrets.items["sabnzbd"].SABNZBD_API_KEY
  tv_category                = "tv"
  use_ssl                    = false
  remove_completed_downloads = true
  remove_failed_downloads    = true
}

resource "sonarr_remote_path_mapping" "sabnzbd" {
  host        = "sabnzbd.default.svc.cluster.local"
  remote_path = "/Downloads/sabnzbd/complete/"
  local_path  = "/media/Downloads/sabnzbd/complete/"
}

resource "sonarr_host" "sonarr" {
  depends_on = [
    sonarr_root_folder.series,
    sonarr_download_client_sabnzbd.sabnzbd,
    sonarr_remote_path_mapping.sabnzbd
  ]
  launch_browser = true
  port = 80
  url_base = ""
  bind_address = "*"
  application_url = ""
  instance_name = "Sonarr"

  authentication = {
    method = "external"
  }
  proxy = {
    enabled = false
    bypass_local_addresses = true
  }
  ssl = {
    enabled = false
    certificate_validation = "enabled"
  }
  logging = {
    log_level = "debug"
    analytics_enabled = false
    log_size_limit = 1
  }
  backup = {
    folder = "Backups"
    interval = 7
    retention = 28
  }
  update = {
    mechanism = "docker"
    branch = "develop"
    update_automatically = false
  }
}
