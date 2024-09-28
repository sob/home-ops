module "homepage" {
  source = "./modules/forward-auth-application"
  slug   = "homepage"

  name   = "Homepage"
  domain = "homepage.${local.cluster_domain}"
  group  = authentik_group.infrastructure.name

  policy_engine_mode      = "any"
  authorization_flow_uuid = data.authentik_flow.default-provider-authorization-implicit-consent.id

  meta_icon = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/homepage.png"
}

resource "authentik_group" "homepage_users" {
  name = "Homepage Users"
}

resource "authentik_policy_binding" "homepage-access-users" {
  target = module.homepage.application_id
  group  = authentik_group.homepage_users.id
  order  = 0
}
