provider "readarr" {
  url     = module.onepassword_readarr.fields.READARR_URL
  api_key = module.onepassword_readarr.fields.READARR_API_KEY
}

resource "readarr_root_folder" "books" {
  path                            = "/media/Library/e-books"
  name                            = "eBooks"
  default_metadata_profile_id     = 1
  default_quality_profile_id      = 1
  default_monitor_option          = "all"
  default_monitor_new_item_option = "all"
  is_calibre_library              = false
  output_profile                  = "default"
}

resource "readarr_download_client_sabnzbd" "sabnzbd" {
  enable                     = true
  priority                   = 1
  name                       = "SABnzbd"
  host                       = "sabnzbd.default.svc.cluster.local"
  port                       = "80"
  api_key                    = module.onepassword_sabnzbd.fields.SABNZBD_API_KEY
  book_category              = "books"
  use_ssl                    = false
  remove_completed_downloads = true
  remove_failed_downloads    = true
}

resource "readarr_remote_path_mapping" "sabnzbd" {
  host        = "sabnzbd.default.svc.cluster.local"
  remote_path = "/Downloads/sabnzbd/complete/"
  local_path  = "/media/Downloads/sabnzbd/complete/"
}

resource "readarr_host" "readarr" {
  depends_on = [
    readarr_root_folder.books,
    readarr_download_client_sabnzbd.sabnzbd,
    readarr_remote_path_mapping.sabnzbd
  ]
  launch_browser = true
  port = 80
  url_base = ""
  bind_address = "*"
  application_url = ""
  instance_name = "Readarr"
  authentication = {
    method = "external"
    password = "password"
    passwordConfirmation = "password"
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
