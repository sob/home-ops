terraform {
  required_providers {
    prowlarr = {
      source = "devopsarr/prowlarr"
      version = "2.4.3"
    }
    radarr = {
      source = "devopsarr/radarr"
      version = "2.3.2"
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
    }
  }
}

provider "onepassword" {
  account = var.onepassword_account
}

module "onepassword_prowlarr" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "STONEHEDGES"
  item   = "prowlarr"
}

module "onepassword_sonarr" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "STONEHEDGES"
  item   = "sonarr"
}

module "onepassword_radarr" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "STONEHEDGES"
  item   = "radarr"
}

module "onepassword_readarr" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "STONEHEDGES"
  item   = "readarr"
}

module "onepassword_lidarr" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "STONEHEDGES"
  item   = "lidarr"
}

module "onepassword_sabnzbd" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "STONEHEDGES"
  item   = "sabnzbd"
}
