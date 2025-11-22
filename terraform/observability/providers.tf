terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    onepassword = {
      source  = "1password/onepassword"
      version = "2.2.1"
    }
    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.0"
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