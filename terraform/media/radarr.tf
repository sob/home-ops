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

resource "radarr_naming" "movies" {
  rename_movies = true
  replace_illegal_characters = true
  colon_replacement_format = "spaceDashSpace"  # Replace with Space Dash Space

  # Movie Folder Format
  # Creates: /media/Library/movies/Movie Title (2024) {imdb-tt0133093}
  movie_folder_format = "{Movie Title} ({Release Year}) {imdb-{ImdbId}}"

  # Standard Movie Format
  # Creates: Movie Title (2024) - [WEBDL-2160p][HDR10][DTS-HD MA 7.1][x265]-ReleaseGroup.mkv
  standard_movie_format = "{Movie Title} ({Release Year}) - {[Quality Full]}{[MediaInfo VideoDynamicRangeType]}{[MediaInfo AudioCodec}{ MediaInfo AudioChannels]}{[MediaInfo VideoCodec]}-{Release Group}"
}

resource "radarr_media_management" "movies" {
  auto_unmonitor_previously_downloaded_movies = true
  auto_rename_folders = false
  create_empty_movie_folders = false
  delete_empty_folders = true
  enable_media_info = true

  import_extra_files = true
  extra_file_extensions = "srt,sub,idx,ass,ssa"  # Subtitle formats

  download_propers_and_repacks = "preferAndUpgrade"
  rescan_after_refresh = "always"
  file_date = "none"
  recycle_bin = ""
  recycle_bin_cleanup_days = 7

  set_permissions_linux = false
  chmod_folder = "755"
  chown_group = ""

  skip_free_space_check_when_importing = false
  minimum_free_space_when_importing = 100  # MB

  copy_using_hardlinks = false  # Can't use hardlinks over NFS
  paths_default_static = false
}

resource "radarr_notification_plex" "plex" {
  name                        = "kubernetes"
  on_download                 = true
  on_upgrade                  = true
  on_rename                   = true
  on_movie_added              = false
  on_movie_delete             = true
  on_movie_file_delete        = true
  on_movie_file_delete_for_upgrade = true

  host        = "plex.default.svc.cluster.local"
  port        = 32400
  use_ssl     = false
  auth_token  = module.secrets.items["plex"].PLEX_TOKEN

  update_library = true
  include_health_warnings = false

  tags = []
}
