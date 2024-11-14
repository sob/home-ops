resource "authentik_brand" "homelab" {
  domain              = module.onepassword_authentik.fields.AUTHENTIK_BRANDING_DOMAIN
  branding_title      = module.onepassword_authentik.fields.AUTHENTIK_BRANDING_TITLE
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  flow_authentication = authentik_flow.authentication.uuid
  flow_invalidation   = authentik_flow.invalidation.uuid
  flow_user_settings  = authentik_flow.user-settings.uuid
}

data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

resource "authentik_service_connection_kubernetes" "local" {
  name  = "local"
  local = true
}
