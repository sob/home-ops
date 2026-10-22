provider "prowlarr" {
  url     = module.secrets.items["prowlarr"].PROWLARR_URL
  api_key = module.secrets.items["prowlarr"].PROWLARR_API_KEY
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
