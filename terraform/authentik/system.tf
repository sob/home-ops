resource "authentik_brand" "homelab" {
  domain              = module.onepassword_authentik.fields.AUTHENTIK_BRANDING_DOMAIN
  branding_title      = module.onepassword_authentik.fields.AUTHENTIK_BRANDING_TITLE
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  flow_authentication = authentik_flow.authentication.uuid
  flow_invalidation   = authentik_flow.invalidation.uuid
  flow_user_settings  = authentik_flow.user-settings.uuid
}

resource "authentik_brand" "halfduplex" {
  domain              = "halfduplex.io"
  branding_title      = "halfduplex.io"
  # Served from the (public) repo via jsdelivr CDN — bypasses authentik's
  # media storage, which changed in 2025.12 (/files prefix, /data/media) and
  # no longer serves volume-mounted files cleanly. Matches the app-icon pattern.
  branding_logo       = "https://cdn.jsdelivr.net/gh/sob/home-ops@main/kubernetes/apps/security/authentik/app/halfduplex.png"
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  branding_custom_css = file("${path.module}/halfduplex-branding.css")
  flow_authentication = authentik_flow.authentication-halfduplex.uuid
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
