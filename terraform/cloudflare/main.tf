terraform {
  backend "s3" {
    bucket = "stone-terraform-state"
    key    = "cloudflare/terraform.tfstate"
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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.27.0"
    }
    onepassword = {
      source = "1password/onepassword"
    }
  }
}

provider "onepassword" {
  account = var.onepassword_account
}

# A dedicated token, scoped to Zone WAF: Edit + Zone: Read on 56kbps.io.
# external-dns keeps its own DNS-only token.
provider "cloudflare" {
  api_token = module.onepassword_cloudflare.fields.CLOUDFLARE_WAF_API_TOKEN
}

module "onepassword_cloudflare" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "STONEHEDGES"
  item   = "cloudflare"
}

data "cloudflare_zone" "main" {
  filter = {
    name = "56kbps.io"
  }
}
