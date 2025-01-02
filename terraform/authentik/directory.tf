
data "authentik_group" "admins" {
  name = "authentik Admins"
}

resource "authentik_group" "media" {
  name         = "media"
  is_superuser = false
}

resource "authentik_group" "home" {
  name         = "home"
  is_superuser = false
}

resource "authentik_group" "observability" {
  name         = "observability"
  is_superuser = false
}

resource "authentik_group" "network" {
  name         = "network"
  is_superuser = false
}

resource "authentik_group" "users" {
  name         = "users"
  is_superuser = false
}

resource "authentik_user" "sob" {
  username = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_SOB_USERNAME
  name     = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_SOB_NAME
  email    = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_SOB_EMAIL
  password = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_SOB_PASSWORD
  groups = [
    data.authentik_group.admins.id,
    resource.authentik_group.home.id,
    resource.authentik_group.media.id,
    resource.authentik_group.network.id,
    resource.authentik_group.observability.id
  ]
}

resource "authentik_user" "lob" {
  username = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_LOB_USERNAME
  name     = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_LOB_NAME
  email    = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_LOB_EMAIL
  groups = [
    resource.authentik_group.home.id,
    resource.authentik_group.media.id
  ]
}

resource "authentik_user" "gob" {
  username = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_GOB_USERNAME
  name     = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_GOB_NAME
  email    = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_GOB_EMAIL
  groups = [
    resource.authentik_group.media.id
  ]
}

resource "authentik_user" "eob" {
  username = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_EOB_USERNAME
  name     = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_EOB_NAME
  email    = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_EOB_EMAIL
  groups = [
    resource.authentik_group.media.id
  ]
}

resource "authentik_user" "cob" {
  username = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_COB_USERNAME
  name     = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_COB_NAME
  email    = module.onepassword_authentik.fields.AUTHENTIK_BLUEPRINTS_USERS_COB_EMAIL
  groups = [
    resource.authentik_group.media.id
  ]
}
