terraform {
  required_providers {
    onepassword = {
      source  = "1password/onepassword"
      version = "2.2.1"
    }
  }
}

data "onepassword_vault" "vault" {
  name = var.vault
}

data "onepassword_item" "items" {
  for_each = toset(var.items)
  vault    = data.onepassword_vault.vault.uuid
  title    = each.key
}
