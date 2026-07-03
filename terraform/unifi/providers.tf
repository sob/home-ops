terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket = "stone-terraform-state"
    key    = "unifi/terraform.tfstate"
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
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "~> 0.53"
    }
    onepassword = {
      source  = "1password/onepassword"
      version = "3.3.1"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
  }
}

provider "onepassword" {
  account = var.onepassword_account
}

provider "unifi" {
  api_url        = nonsensitive(local.unifi_fields["URL"])
  api_key        = sensitive(local.unifi_fields["API_KEY"])
  allow_insecure = true
}
