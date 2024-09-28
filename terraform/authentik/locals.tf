locals {
  cluster_domain   = module.onepassword_authentik.fields.AUTHENTIK_BRANDING_DOMAIN
  authentik_domain = "sso.${local.cluster_domain}"
}
