terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.8.0"
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
  url   = module.onepassword_authentik.fields.AUTHENTIK_URL
  token = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_TOKEN
}

module "onepassword_authentik" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "STONEHEDGES"
  item   = "authentik"
}
