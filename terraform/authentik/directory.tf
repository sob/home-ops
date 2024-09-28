data "authentik_group" "admins" {
  name = "authentik Admins"
}

resource "authentik_group" "users" {
  name         = "users"
  is_superuser = false
}

resource "authentik_group" "infrastructure" {
  name         = "Infrastructure"
  is_superuser = false
}

resource "authentik_group" "monitoring" {
  name         = "Monitoring"
  is_superuser = false
}

resource "authentik_group" "applications" {
  name         = "Applications"
  is_superuser = false
}

resource "authentik_user" "admin" {
  username = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_USERNAME
  name     = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_NAME
  email    = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_EMAIL
  password = module.onepassword_authentik.fields.AUTHENTIK_BOOTSTRAP_PASSWORD
  groups = [
    data.authentik_group.admins.id,
    authentik_group.users.id,
    authentik_group.whoami_users.id
  ]
}
