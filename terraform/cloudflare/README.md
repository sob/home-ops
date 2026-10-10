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

## Apply
The zone's custom-rules entrypoint already existed (made in the dashboard), so
`firewall.tf` has an `import` block for it, and the first plan shows an import
rather than a create. Terraform owns that ruleset's **whole** rule list.

```sh
terraform init
terraform plan -var onepassword_account=<account>    # expect: 1 to import, 1 to change
terraform apply -var onepassword_account=<account>
```

The first plan replaces the old disabled dashboard rule "Block all non-US
requests". Its expression, `(country ne "US") or (country ne "PL")`, matched
every request, so it could never be enabled. It's replaced by the login-host
allowlist.

After the first successful apply, the `import` block can stay (it's a no-op
once the resource is in state) or be deleted.
