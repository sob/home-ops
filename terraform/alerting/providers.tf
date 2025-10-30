terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.0"
    }
    onepassword = {
      source  = "1password/onepassword"
      version = "2.2.0"
    }
  }
}

provider "onepassword" {
  account = var.onepassword_account
}