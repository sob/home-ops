provider "lidarr" {
  url     = module.secrets.items["lidarr"].LIDARR_URL
  api_key = module.secrets.items["lidarr"].LIDARR_API_KEY
}

data "lidarr_quality_profile" "lossless" {
  name = "Lossless"
}

data "lidarr_metadata_profile" "standard" {
  name = "Standard"
}

resource "lidarr_root_folder" "music" {
  path = "/media/Library/music"
  name = "DOOM"
  metadata_profile_id = data.lidarr_metadata_profile.standard.id
  monitor_option = "all"
  new_item_monitor_option = "all"
  quality_profile_id = data.lidarr_quality_profile.lossless.id
}

resource "lidarr_download_client_sabnzbd" "sabnzbd" {
  enable                     = true
  priority                   = 1
  name                       = "SABnzbd"
  host                       = "sabnzbd.default.svc.cluster.local"
  port                       = "80"
  api_key                    = module.secrets.items["sabnzbd"].SABNZBD_API_KEY
  music_category             = "audio"
  use_ssl                    = false
  remove_completed_downloads = true
  remove_failed_downloads    = true
}

resource "lidarr_remote_path_mapping" "sabnzbd" {
  host        = "sabnzbd.default.svc.cluster.local"
  remote_path = "/Downloads/sabnzbd/complete/"
  local_path  = "/media/Downloads/sabnzbd/complete/"
}

resource "lidarr_host" "lidarr" {
  depends_on = [ lidarr_root_folder.music, lidarr_download_client_sabnzbd.sabnzbd ]
  launch_browser = true
  port = 80
  url_base = ""
  bind_address = "*"
  application_url = ""
  instance_name = "Lidarr"

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
    log_size_limit = 0
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
