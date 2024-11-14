
resource "authentik_source_plex" "plex" {
  name                = "Plex"
  slug                = "plex"
  client_id           = module.onepassword_authentik.fields.PLEX_CLIENT_ID
  plex_token          = module.onepassword_authentik.fields.PLEX_TOKEN
  allow_friends       = true
  user_matching_mode  = "email_link"
  allowed_servers = [
    module.onepassword_authentik.fields.PLEX_SERVER_ID
  ]
  authentication_flow = data.authentik_flow.default-source-authentication.id
  enrollment_flow     = data.authentik_flow.default-source-enrollment.id
}

resource "authentik_source_oauth" "apple" {
  name                = "Apple"
  slug                = "apple"
  consumer_key        = module.onepassword_authentik.fields.APPLE_CONSUMER_KEY
  consumer_secret     = module.onepassword_authentik.fields.APPLE_CONSUMER_SECRET
  provider_type       = "apple"
  user_matching_mode  = "email_link"
  authentication_flow = data.authentik_flow.default-source-authentication.id
  enrollment_flow     = data.authentik_flow.default-source-enrollment.id
}
