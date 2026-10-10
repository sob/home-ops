locals {
  # Countries allowed to reach the SSO login host (ISO 3166-1 alpha-2).
  # Everyone else is blocked at Cloudflare's edge, before the tunnel.
  # Add a country before travelling there.
  login_allowed_countries = ["US"]

  login_host = "login.56kbps.io"
}

# The zone's single custom-rules entrypoint (phase http_request_firewall_custom).
# Terraform owns every rule in it: any rule added in the dashboard is removed
# on the next apply. If the zone already has this ruleset, import it first
# (see README.md) and carry its existing rules over here.
resource "cloudflare_ruleset" "custom_firewall" {
  zone_id     = data.cloudflare_zone.main.zone_id
  name        = "default"
  description = "Custom firewall rules (managed by terraform/cloudflare)"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [
    {
      ref         = "login_geo_allowlist"
      description = "SSO login: block countries outside the allowlist"
      expression  = "(http.host eq \"${local.login_host}\" and not ip.src.country in {${join(" ", [for c in local.login_allowed_countries : "\"${c}\""])}})"
      action      = "block"
      enabled     = true
    },
  ]
}
