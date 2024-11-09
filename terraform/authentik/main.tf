terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2024.10.0"
    }

    onepassword = {
      source = "1password/onepassword"
    }
  }
}

provider "authentik" {
  url   = module.onepassword_authentik.fields.AUTHENTIK_URL
  token = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_TOKEN
}

provider "onepassword" {
  account = var.onepassword_account
}

module "onepassword_authentik" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "STONEHEDGES"
  item   = "authentik"
}

resource "authentik_service_connection_kubernetes" "local" {
  name       = "local"
  local      = true
  verify_ssl = false
}
