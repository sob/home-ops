locals {
  # Countries allowed to reach the SSO login host (ISO 3166-1 alpha-2).
  # Everyone else is blocked at Cloudflare's edge, before the tunnel.
  # Add a country before travelling there.
  login_allowed_countries = ["US", "PL"]

  login_host = "login.56kbps.io"
}

# The zone already has its custom-rules entrypoint (created in the dashboard,
# 2025-11-14), so adopt it rather than create a second one, which the API
# rejects. A zone has exactly one per phase.
import {
  to = cloudflare_ruleset.custom_firewall
  id = "zones/5f5ac944f9e6a06e2687cc890d8e9b25/f4604c76706e418c89672278c0c22d2d"
}

# The zone's single custom-rules entrypoint (phase http_request_firewall_custom).
# Terraform owns every rule in it: any rule added in the dashboard is removed
# on the next apply.
#
# Replaces the dashboard rule "Block all non-US requests" (disabled):
#   (ip.geoip.country ne "US") or (ip.geoip.country ne "PL")
# That expression is true for every request (nothing is both US and PL), so
# enabled it blocked everyone. The intent, US and Poland only, is the
# `not ... in {...}` set below, scoped to the login host.
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
