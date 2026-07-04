terraform {
  backend "s3" {
    bucket = "stone-terraform-state"
    key    = "observability/terraform.tfstate"
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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    onepassword = {
      source  = "1password/onepassword"
      version = "3.3.1"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "4.39.1"
    }
  }
}

provider "kubernetes" {
  config_path = "../../.kubeconfig"
}

provider "onepassword" {
  # Using OnePassword CLI authentication
  # Requires 'op' CLI to be installed and authenticated
  account = var.onepassword_account
}

provider "grafana" {
  url          = local.grafana_url
  auth         = local.grafana_auth
  http_headers = {
    "Content-Type" = "application/json"
  }
  retries      = 3
  retry_wait   = 5
}
