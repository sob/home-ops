# Adopt the existing arr objects into the R2 state. The earlier state was
# local and is gone. IDs come from each app's API. Delete this file after
# the first apply.
import {
  to = sonarr_root_folder.series
  id = "2"
}
import {
  to = sonarr_download_client_sabnzbd.sabnzbd
  id = "1"
}
import {
  to = sonarr_remote_path_mapping.sabnzbd
  id = "1"
}
import {
  to = sonarr_notification_plex.plex
  id = "1"
}
import {
  to = sonarr_naming.series
  id = "1"
}
import {
  to = sonarr_media_management.series
  id = "1"
}

import {
  to = radarr_root_folder.movies
  id = "5"
}
import {
  to = radarr_download_client_sabnzbd.sabnzbd
  id = "2"
}
import {
  to = radarr_remote_path_mapping.sabnzbd
  id = "1"
}
import {
  to = radarr_notification_plex.plex
  id = "1"
}
import {
  to = radarr_naming.movies
  id = "1"
}
import {
  to = radarr_media_management.movies
  id = "1"
}

import {
  to = lidarr_root_folder.music
  id = "1"
}
import {
  to = lidarr_remote_path_mapping.sabnzbd
  id = "1"
}

import {
  to = prowlarr_application_radarr.radarr
  id = "1"
}
import {
  to = prowlarr_application_lidarr.lidarr
  id = "2"
}
import {
  to = prowlarr_application_sonarr.sonarr
  id = "3"
}
import {
  to = prowlarr_indexer.nzbfinder
  id = "1"
}
import {
  to = prowlarr_indexer.nzbgeek
  id = "2"
}
import {
  to = prowlarr_indexer.nzbplanet
  id = "4"
}

# General settings (auth, logging, updates) are no longer managed here:
# Sonarr, Radarr, Lidarr and Prowlarr now require Allowed Hosts when auth is
# disabled for local addresses, and these provider versions can't set it.
# Forget them without touching the apps.
removed {
  from = sonarr_host.sonarr
  lifecycle {
    destroy = false
  }
}
removed {
  from = radarr_host.radarr
  lifecycle {
    destroy = false
  }
}
removed {
  from = lidarr_host.lidarr
  lifecycle {
    destroy = false
  }
}
removed {
  from = prowlarr_host.stonehedges
  lifecycle {
    destroy = false
  }
}
