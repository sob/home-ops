
data "authentik_group" "admins" {
  name = "authentik Admins"
}

resource "authentik_group" "downloads" {
  name         = "Downloads"
  is_superuser = false
}

resource "authentik_group" "grafana_admin" {
  name         = "Grafana Admins"
  is_superuser = false
}

resource "authentik_group" "headscale" {
  name         = "Headscale"
  is_superuser = false
}

resource "authentik_group" "home" {
  name         = "Home"
  is_superuser = false
}

resource "authentik_group" "infrastructure" {
  name         = "Infrastructure"
  is_superuser = false
}

resource "authentik_group" "monitoring" {
  name         = "Monitoring"
  is_superuser = false
  parent       = resource.authentik_group.grafana_admin.id
}

resource "authentik_group" "users" {
  name         = "users"
  is_superuser = false
}

data "authentik_group" "lookup" {
  for_each = local.applications
  name     = each.value.group.name
}

resource "authentik_policy_binding" "application_policy_binding" {
  for_each = local.applications

  target = authentik_application.application[each.key].uuid
  group  = data.authentik_group.lookup[each.key].id #authentik_application.application[each.key].group.id
  #group  = data.authentik_group.lookup[each.key].id
  order  = 0
}

resource "authentik_user" "admin" {
  username = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_USERNAME
  name     = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_NAME
  email    = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_EMAIL
  password = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_PASSWORD
  groups = [
    data.authentik_group.admins.id,
    authentik_group.users.id
  ]
}
