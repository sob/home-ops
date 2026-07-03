data "onepassword_vault" "stonehedges" {
  name = "STONEHEDGES"
}

data "onepassword_item" "unifi" {
  vault = data.onepassword_vault.stonehedges.uuid
  title = "unifi"
}

locals {
  unifi_fields = {
    for field in flatten([for section in data.onepassword_item.unifi.section : section.field]) :
    field.label => field.value
  }
}

data "sops_file" "clients" {
  source_file = "${path.module}/clients.sops.yaml"
}

locals {
  clients = {
    for key, value in nonsensitive(data.sops_file.clients.data) :
    trimprefix(key, "clients.") => value
    if startswith(key, "clients.")
  }
}

resource "unifi_client" "client" {
  for_each = local.clients

  mac  = each.key
  name = each.value
}
