terraform {
  backend "s3" {
    bucket = "stone-terraform-state"
    key    = "media/terraform.tfstate"
    endpoints = {
      s3 = "https://c22e00d98ac0a9cf99b28d585113a449.r2.cloudflarestorage.com"
    }
    region                      = "auto"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  required_providers {
    prowlarr = {
      source  = "devopsarr/prowlarr"
      version = "3.2.2"
    }
    radarr = {
      source  = "devopsarr/radarr"
      version = "2.5.0"
    }
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "3.5.0"
    }

    lidarr = {
      source  = "devopsarr/lidarr"
      version = "1.13.0"
    }
    onepassword = {
      source  = "1password/onepassword"
      version = "3.4.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 3.0"
    }
  }
}

provider "onepassword" {
  account = var.onepassword_account
}

module "secrets" {
  source = "./modules/onepassword"
  vault  = "STONEHEDGES"
  items  = ["lidarr", "prowlarr", "sonarr", "radarr", "sabnzbd", "cluster-secrets", "plex"]
}

locals {
  # Public domain, kept out of git
  domain = nonsensitive(module.secrets.items["cluster-secrets"].SECRET_DOMAIN)
}
