terraform {
  required_providers {
    prowlarr = {
      source = "devopsarr/prowlarr"
      version = "3.0.2"
    }
    radarr = {
      source = "devopsarr/radarr"
      version = "2.3.3"
    }
    sonarr = {
      source = "devopsarr/sonarr"
      version = "3.4.0"
    }
    readarr = {
      source = "devopsarr/readarr"
      version = "2.1.0"
    }

    lidarr = {
      source = "devopsarr/lidarr"
      version = "1.13.0"
    }
    onepassword = {
      source = "1password/onepassword"
      version = "2.2.1"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0"
    }
  }
}

provider "onepassword" {
  account = var.onepassword_account
}

module "secrets" {
  source = "./modules/onepassword"
  vault = "STONEHEDGES"
  items = ["lidarr", "prowlarr", "sonarr", "radarr", "readarr", "sabnzbd", "cluster-secrets", "plex"]
}
