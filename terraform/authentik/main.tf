terraform {
  backend "s3" {
    bucket = "stone-terraform-state"
    key    = "authentik/terraform.tfstate"
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
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.1"
    }

    onepassword = {
      source = "1password/onepassword"
    }
  }
}

provider "onepassword" {
  account = var.onepassword_account
}

provider "authentik" {
  url      = var.authentik_url
  token    = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_TOKEN
  insecure = true
}

module "onepassword_authentik" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "STONEHEDGES"
  item   = "authentik"
}
