locals {
  main_proxy_provider_ids = [
    authentik_provider_proxy.main["bazarr"].id,
    authentik_provider_proxy.main["echo_server"].id,
    authentik_provider_proxy.main["homeassistant"].id,
    authentik_provider_proxy.main["lidarr"].id,
    authentik_provider_proxy.main["prowlarr"].id,
    authentik_provider_proxy.main["radarr"].id,
    authentik_provider_proxy.main["readarr"].id,
    authentik_provider_proxy.main["sonarr"].id,
    authentik_provider_proxy.main["wizarr"].id,
  ]

  halfduplex_proxy_provider_ids = [
    authentik_provider_proxy.main["enigma_code"].id,
    authentik_provider_proxy.main["enigma_draw"].id,
  ]
}

resource "authentik_outpost" "main" {
  name               = "56kbps"
  service_connection = authentik_service_connection_kubernetes.local.id
  protocol_providers = local.main_proxy_provider_ids
  config = jsonencode({
    "log_level"                      = "info"
    "docker_labels"                  = null
    "authentik_host"                 = "https://sso.${local.cluster_domain}/"
    "docker_network"                 = null
    "container_image"                = null
    "docker_map_ports"               = true
    "kubernetes_replicas"            = 1
    "kubernetes_namespace"           = "security"
    "authentik_host_browser"         = ""
    "object_naming_template"         = "ak-outpost-%(name)s"
    "authentik_host_insecure"        = false
    "kubernetes_json_patches"        = null
    "kubernetes_service_type"        = "ClusterIP"
    "kubernetes_image_pull_secrets"  = []
    "kubernetes_disabled_components" = ["ingress"]
  })
}

resource "authentik_outpost" "halfduplex" {
  name               = "halfduplex"
  service_connection = authentik_service_connection_kubernetes.local.id
  protocol_providers = local.halfduplex_proxy_provider_ids
  config = jsonencode({
    "log_level"                      = "info"
    "docker_labels"                  = null
    "authentik_host"                 = "https://sso.halfduplex.io/"
    "docker_network"                 = null
    "container_image"                = null
    "docker_map_ports"               = true
    "kubernetes_replicas"            = 1
    "kubernetes_namespace"           = "security"
    "authentik_host_browser"         = ""
    "object_naming_template"         = "ak-outpost-%(name)s"
    "authentik_host_insecure"        = false
    "kubernetes_json_patches"        = null
    "kubernetes_service_type"        = "ClusterIP"
    "kubernetes_image_pull_secrets"  = []
    "kubernetes_disabled_components" = ["ingress"]
  })
}
