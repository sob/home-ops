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

# The SABnzbd download client is configured in Lidarr by hand: provider
# 1.13.0 cannot read Lidarr 3.x download clients ("UsenetDownloadProtocol is
# not a valid DownloadProtocol", devopsarr/terraform-provider-lidarr#255).

resource "lidarr_remote_path_mapping" "sabnzbd" {
  host        = "sabnzbd.default.svc.cluster.local"
  remote_path = "/Downloads/sabnzbd/complete/"
  local_path  = "/media/Downloads/sabnzbd/complete/"
}
