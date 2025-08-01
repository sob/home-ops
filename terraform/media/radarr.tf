provider "radarr" {
  url     = module.secrets.items["radarr"].RADARR_URL
  api_key = module.secrets.items["radarr"].RADARR_API_KEY
}

resource "radarr_root_folder" "movies" {
  path = "/media/Library/movies"
}

resource "radarr_download_client_sabnzbd" "sabnzbd" {
  enable                     = true
  priority                   = 1
  name                       = "SABnzbd"
  host                       = "sabnzbd.default.svc.cluster.local"
  port                       = "80"
  api_key                    = module.secrets.items["sabnzbd"].SABNZBD_API_KEY
  movie_category             = "movies"
  use_ssl                    = false
  remove_completed_downloads = true
  remove_failed_downloads    = true
}

resource "radarr_remote_path_mapping" "sabnzbd" {
  host        = "sabnzbd.default.svc.cluster.local"
  remote_path = "/Downloads/sabnzbd/complete/"
  local_path  = "/media/Downloads/sabnzbd/complete/"
}

resource "radarr_host" "radarr" {
  depends_on = [ radarr_root_folder.movies, radarr_download_client_sabnzbd.sabnzbd ]
  launch_browser = true
  port = 80
  url_base = ""
  bind_address = "*"
  application_url = ""
  instance_name = "Radarr"

  authentication = {
    method = "external"
  }
  proxy = {
    enabled = false
    bypass_local_addresses = true
    port = 8080
  }
  ssl = {
    enabled = false
    certificate_validation = "enabled"
    port = 9898
  }
  logging = {
    log_level = "info"
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
