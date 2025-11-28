terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.10.1"
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
