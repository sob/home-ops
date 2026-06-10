terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "4.31.3"
    }
    onepassword = {
      source  = "1password/onepassword"
      version = "3.3.1"
    }
  }
}

provider "onepassword" {
  account = var.onepassword_account
}