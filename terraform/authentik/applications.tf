locals {
  applications = {
    grafana = {
      client_id     = module.onepassword_authentik.fields.GRAFANA_CLIENT_ID
      client_secret = module.onepassword_authentik.fields.GRAFANA_CLIENT_SECRET
      icon_url      = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/grafana.png"
      redirect_uri  = "https://grafana.${local.cluster_domain}/login/generic_oauth"
      launch_url    = "https://grafana.${local.cluster_domain}/login/generic_oauth"
      group         = resource.authentik_group.observability
    },
    lubelog = {
      client_id     = module.onepassword_authentik.fields.LUBELOG_CLIENT_ID
      client_secret = module.onepassword_authentik.fields.LUBELOG_CLIENT_SECRET
      icon_url      = "https://demo.lubelogger.com/defaults/lubelogger_icon_72.png"
      redirect_uri  = "https://lubelog.${local.cluster_domain}/Login/RemoteAuth"
      launch_url    = "https://lubelog.${local.cluster_domain}/Login/RemoteAuth"
      group         = resource.authentik_group.home
    },
    gatus = {
      client_id     = module.onepassword_authentik.fields.GATUS_CLIENT_ID
      client_secret = module.onepassword_authentik.fields.GATUS_CLIENT_SECRET
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/gatus.png"
      redirect_uri  = "https://status.${local.cluster_domain}/authorization-code/callback"
      launch_url    = "https://status.${local.cluster_domain}"
      group         = resource.authentik_group.observability
    },
    homarr = {
      client_id     = module.onepassword_authentik.fields.HOMARR_CLIENT_ID
      client_secret = module.onepassword_authentik.fields.HOMARR_CLIENT_SECRET
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/homarr.png"
      redirect_uri  = "https://homarr.${local.cluster_domain}/api/auth/callback/oidc"
      launch_url    = "https://homarr.${local.cluster_domain}"
      group         = resource.authentik_group.home
    },
  }

  proxy_applications = {
    adminer = {
      external_host = "https://postgres.56kbps.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/adminer.png"
      group         = resource.authentik_group.observability
      cookie_domain = "56kbps.io"
      namespace     = "database"
    },
    bazarr = {
      external_host   = "https://bazarr.56kbps.io"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/bazarr.png"
      group           = resource.authentik_group.media
      cookie_domain   = "56kbps.io"
      skip_path_regex = "^/api([/?].*)?"
    },
    dozzle = {
      external_host = "https://logs.56kbps.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/dozzle.png"
      group         = resource.authentik_group.observability
      cookie_domain = "56kbps.io"
      namespace     = "observability"
    },
    echo_server = {
      external_host = "https://echo-server.56kbps.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/web-check.png"
      group         = resource.authentik_group.network
      cookie_domain = "56kbps.io"
    },
    enigma_code = {
      external_host = "https://edit.halfduplex.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/code-server.png"
      group         = resource.authentik_group.network
      cookie_domain = "halfduplex.io"
    },
    enigma_draw = {
      external_host = "https://draw.halfduplex.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/draw.png"
      group         = resource.authentik_group.network
      cookie_domain = "halfduplex.io"
    },
    audiobookshelf = {
      external_host = "https://books.56kbps.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/audiobookshelf.png"
      group         = resource.authentik_group.media
      cookie_domain = "56kbps.io"
      # Audiobookshelf's mobile and web clients authenticate against its own
      # user database over these paths. Forward-auth must not intercept them
      # or the apps cannot log in or stream.
      skip_path_regex = "^/(api|login|status|healthcheck|hls|feed|public)([/?].*)?"
    },
    homeassistant = {
      external_host = "https://hass.56kbps.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/home-assistant-alt.png"
      group         = resource.authentik_group.home
      cookie_domain = "56kbps.io"
      # The companion app is an OAuth client, not a browser session: it
      # authenticates against /auth/* and then talks over /api/* (REST,
      # /api/websocket, /api/webhook/<id>). Forward-auth on those paths breaks
      # login and every push notification. The frontend/static paths are here
      # because the app renders the login page in a webview and needs its
      # assets to load.
      #
      # Consequence worth being explicit about: /auth is the login surface, so
      # skipping it means Authentik can be bypassed by going straight there and
      # using Home Assistant's own login. There is no path set that keeps a UI
      # client working AND forces every login through Authentik. Home
      # Assistant's own auth is the control on these paths — keep ip_ban on and
      # TOTP enabled.
      skip_path_regex = "^/(api|auth|static|frontend_latest|frontend_es5|local|media|service_worker\\.js|manifest\\.json)([/?].*)?"
    },
    lidarr = {
      external_host   = "https://lidarr.56kbps.io"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/lidarr.png"
      group           = resource.authentik_group.media
      cookie_domain   = "56kbps.io"
      skip_path_regex = "^/api([/?].*)?"
    },
    prowlarr = {
      external_host   = "https://prowlarr.56kbps.io"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/prowlarr.png"
      group           = resource.authentik_group.media
      cookie_domain   = "56kbps.io"
      skip_path_regex = "^/api([/?].*)?"
    },
    radarr = {
      external_host   = "https://radarr.56kbps.io"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/radarr.png"
      group           = resource.authentik_group.media
      cookie_domain   = "56kbps.io"
      skip_path_regex = "^/api([/?].*)?"
    },
    readarr = {
      external_host   = "https://readarr.56kbps.io"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/readarr.png"
      group           = resource.authentik_group.media
      cookie_domain   = "56kbps.io"
      skip_path_regex = "^/api([/?].*)?"
    },
    sabnzbd = {
      external_host = "https://sab.56kbps.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/sabnzbd.png"
      group         = resource.authentik_group.media
      cookie_domain = "56kbps.io"
    },
    sonarr = {
      external_host   = "https://sonarr.56kbps.io"
      icon_url        = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/sonarr.png"
      group           = resource.authentik_group.media
      cookie_domain   = "56kbps.io"
      skip_path_regex = "^/api([/?].*)?"
    },
    tautulli = {
      external_host = "https://tautulli.56kbps.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/tautulli.png"
      group         = resource.authentik_group.media
      cookie_domain = "56kbps.io"
    },
    qbittorrent = {
      external_host = "https://qbittorrent.56kbps.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/qbittorrent.png"
      group         = resource.authentik_group.media
      cookie_domain = "56kbps.io"
    },
    wizarr = {
      external_host = "https://join.56kbps.io"
      icon_url      = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/wizarr.png"
      group         = resource.authentik_group.media
      cookie_domain = "56kbps.io"
    },
  }
}

resource "authentik_provider_proxy" "main" {
  for_each                      = local.proxy_applications
  name                          = "k8s/stonehedges.net/${lookup(local.proxy_applications[each.key], "namespace", "default")}/${each.key}"
  external_host                 = lookup(local.proxy_applications[each.key], "external_host", null)
  internal_host                 = lookup(local.proxy_applications[each.key], "internal_host", null)
  basic_auth_enabled            = lookup(local.proxy_applications[each.key], "basic_auth_enabled", false)
  basic_auth_password_attribute = lookup(local.proxy_applications[each.key], "basic_auth_password_attribute", null)
  basic_auth_username_attribute = lookup(local.proxy_applications[each.key], "basic_auth_username_attribute", null)
  mode                          = lookup(local.proxy_applications[each.key], "mode", "forward_single")
  cookie_domain                 = lookup(local.proxy_applications[each.key], "cookie_domain", "${local.cluster_domain}")
  authentication_flow           = authentik_flow.authentication.uuid
  authorization_flow            = authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow             = data.authentik_flow.default-provider-invalidation-flow.id
  access_token_validity         = lookup(local.proxy_applications[each.key], "access_token_validity", "hours=4")
  property_mappings             = lookup(local.proxy_applications[each.key], "property_mappings", null)
  skip_path_regex               = lookup(local.proxy_applications[each.key], "skip_path_regex", null)
}

resource "authentik_application" "proxy_application" {
  for_each           = local.proxy_applications
  name               = title(each.key)
  slug               = lookup(local.proxy_applications[each.key], "slug", each.key)
  protocol_provider  = authentik_provider_proxy.main[each.key].id
  group              = each.value.group.name
  open_in_new_tab    = true
  meta_icon          = each.value.icon_url
  meta_launch_url    = lookup(local.proxy_applications[each.key], "external_host", null)
  policy_engine_mode = "all"
}

resource "authentik_policy_binding" "proxy_application_policy_binding" {
  for_each = local.proxy_applications

  target = authentik_application.proxy_application[each.key].uuid
  group  = each.value.group.id
  order  = 0
}

// -----------------------------------------------------------------------------
// OAUTH
// -----------------------------------------------------------------------------

resource "authentik_provider_oauth2" "oauth2" {
  for_each              = local.applications
  name                  = "k8s/stonehedges.net/${lookup(local.applications[each.key], "namespace", "default")}/${each.key}"
  client_id             = each.value.client_id
  client_secret         = each.value.client_secret
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings     = data.authentik_property_mapping_provider_scope.oauth2.ids
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = each.value.redirect_uri
    }
  ]
}

resource "authentik_application" "application" {
  for_each           = local.applications
  name               = title(each.key)
  slug               = lookup(local.applications[each.key], "slug", each.key)
  protocol_provider  = authentik_provider_oauth2.oauth2[each.key].id
  group              = each.value.group.name
  open_in_new_tab    = true
  meta_icon          = each.value.icon_url
  meta_launch_url    = each.value.launch_url
  policy_engine_mode = "all"
}

resource "authentik_policy_binding" "application_policy_binding" {
  for_each = local.applications

  target = authentik_application.application[each.key].uuid
  group  = each.value.group.id
  order  = 0
}
