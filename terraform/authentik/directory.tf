
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
