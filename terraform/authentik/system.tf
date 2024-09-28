resource "authentik_brand" "homelab" {
  domain              = module.onepassword_authentik.fields.AUTHENTIK_BRANDING_DOMAIN
  branding_title      = module.onepassword_authentik.fields.AUTHENTIK_BRANDING_TITLE
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
  branding_favicon    = "/static/dist/assets/icons/icon.png"
#  flow_authentication = data.authentik_flow.default-invalidation-flow.id
#  flow_invalidation   = data.authentik_flow.default-invalidation-flow.id
#  flow_user_settings  = data.authentik_flow.default-user-settings-flow.id
}
