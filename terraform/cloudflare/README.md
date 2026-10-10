# terraform/cloudflare

Cloudflare WAF rules for `56kbps.io`. Currently one rule: only the countries in
`local.login_allowed_countries` (firewall.tf) can reach `login.56kbps.io`
(Tinyauth and its bridge); everyone else gets Cloudflare's block page.

Only `login.56kbps.io` is restricted. Apps with their own clients (Plex,
Jellyfin, Seerr, the Home Assistant app, *arr API paths) keep working while
travelling. `halfduplex.io` is a separate zone and isn't touched.

## Credentials
- `CLOUDFLARE_WAF_API_TOKEN` in the 1Password `cloudflare` item: a Cloudflare
  API token with **Zone → Zone WAF: Edit** and **Zone → Zone: Read**, for the
  `56kbps.io` zone only
- State: R2 (`stone-terraform-state/cloudflare/terraform.tfstate`), with the
  `AWS_*` credentials from `terraform/.mise.toml`

## First apply
A zone has one custom-rules entrypoint ruleset. If one already exists (for
example from the dashboard), import it before the first apply, or the apply
fails. Copy any rules it contains into `firewall.tf` first, because Terraform
replaces the ruleset's whole rule list:

```sh
terraform init
# Find an existing entrypoint (404 means none, so skip the import):
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/<zone_id>/rulesets/phases/http_request_firewall_custom/entrypoint" | jq '.result | {id, rules: [.rules[]? | {description, expression, action}]}'
terraform import cloudflare_ruleset.custom_firewall 'zones/<zone_id>/<ruleset_id>'
terraform plan -var onepassword_account=<account>
```
