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

resource "sonarr_naming" "series" {
  rename_episodes = true
  replace_illegal_characters = true
  colon_replacement_format = 4  # Replace with Space Dash Space
  multi_episode_style = 0  # Extend

  # Series Folder Format
  # Creates: /media/Library/series/Series Title (2024) {tvdb-12345}
  series_folder_format = "{Series Title} ({Series Year}) {tvdb-{TvdbId}}"

  # Season Folder Format
  # Creates: Season 01
  season_folder_format = "Season {season:00}"

  # Specials Folder Format
  specials_folder_format = "Specials"

  # Standard Episode Format
  # Creates: Series Title (2024) - S01E01 - Episode Title - [WEBDL-2160p][HDR10][DTS-HD MA 5.1][x265]-ReleaseGroup.mkv
  standard_episode_format = "{Series Title} ({Series Year}) - S{season:00}E{episode:00} - {Episode Title} - {[Quality Full]}{[MediaInfo VideoDynamicRangeType]}{[MediaInfo AudioCodec}{ MediaInfo AudioChannels]}{[MediaInfo VideoCodec]}-{Release Group}"

  # Daily Episode Format (for daily shows like talk shows)
  daily_episode_format = "{Series Title} ({Series Year}) - {Air-Date} - {Episode Title} - {[Quality Full]}{[MediaInfo VideoDynamicRangeType]}{[MediaInfo AudioCodec}{ MediaInfo AudioChannels]}{[MediaInfo VideoCodec]}-{Release Group}"

  # Anime Episode Format
  anime_episode_format = "{Series Title} ({Series Year}) - S{season:00}E{episode:00} - {absolute:000} - {Episode Title} - {[Quality Full]}{[MediaInfo VideoDynamicRangeType]}{[MediaInfo AudioCodec}{ MediaInfo AudioChannels]}{[MediaInfo VideoCodec]}-{Release Group}"
}

resource "sonarr_media_management" "series" {
  unmonitor_previous_episodes = true
  hardlinks_copy = false  # Can't use hardlinks over NFS
  create_empty_folders = false
  delete_empty_folders = true
  enable_media_info = true

  import_extra_files = true
  extra_file_extensions = "srt,sub,idx,ass,ssa"  # Subtitle formats

  download_propers_repacks = "preferAndUpgrade"
  rescan_after_refresh = "always"
  file_date = "none"
  recycle_bin_path = ""
  recycle_bin_days = 7

  set_permissions = false
  chmod_folder = "755"
  chown_group = ""

  skip_free_space_check = false
  minimum_free_space = 100  # MB

  # Episode Title Required
  episode_title_required = "always"
}

resource "sonarr_notification_plex" "plex" {
  name                          = "kubernetes"
  on_download                   = true
  on_upgrade                    = true
  on_rename                     = true
  on_series_add                 = false
  on_series_delete              = true
  on_episode_file_delete        = true
  on_episode_file_delete_for_upgrade = true
  on_import_complete            = false

  host        = "plex-app.default.svc.cluster.local"
  port        = 32400
  use_ssl     = false
  auth_token  = module.secrets.items["plex"].PLEX_TOKEN

  update_library = true
  include_health_warnings = false

  tags = []
}
