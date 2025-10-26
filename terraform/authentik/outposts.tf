locals {
  internal_proxy_provider_ids = [
    authentik_provider_proxy.main["bazarr"].id,
    authentik_provider_proxy.main["lidarr"].id,
    authentik_provider_proxy.main["prowlarr"].id,
    authentik_provider_proxy.main["radarr"].id,
    authentik_provider_proxy.main["readarr"].id,
    authentik_provider_proxy.main["sonarr"].id,
  ]

  halfduplex_proxy_provider_ids = [
    authentik_provider_proxy.main["enigma_code"].id,
  ]

  external_proxy_provider_ids = [
    authentik_provider_proxy.main["echo_server"].id,
    authentik_provider_proxy.main["homeassistant"].id,
    authentik_provider_proxy.main["wizarr"].id,
  ]
}

resource "authentik_outpost" "internal" {
  name               = "internal"
  service_connection = authentik_service_connection_kubernetes.local.id
  protocol_providers = local.internal_proxy_provider_ids
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
    "kubernetes_ingress_class_name"  = "internal"
    "kubernetes_disabled_components" = []
    "kubernetes_ingress_annotations" = {
      "external-dns.alpha.kubernetes.io/is-public" : "false"
      "external-dns.alpha.kubernetes.io/target" : "internal.${local.cluster_domain}"
      "nginx.ingress.kubernetes.io/proxy-buffers" : "8 16k"
      "nginx.ingress.kubernetes.io/proxy-busy-buffers-size" : "32k"
    }
    "kubernetes_ingress_secret_name" = "56kbps-io-production-tls"
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
    "kubernetes_ingress_class_name"  = "internal"
    "kubernetes_disabled_components" = []
    "kubernetes_ingress_annotations" = {
      "external-dns.alpha.kubernetes.io/is-public" : "false"
      "external-dns.alpha.kubernetes.io/target" : "internal.${local.cluster_domain}"
      "nginx.ingress.kubernetes.io/proxy-buffers" : "8 16k"
      "nginx.ingress.kubernetes.io/proxy-busy-buffers-size" : "32k"
    }
    "kubernetes_ingress_secret_name" = "halfduplex-io-production-tls"
  })
}

resource "authentik_outpost" "external" {
  name               = "external"
  service_connection = authentik_service_connection_kubernetes.local.id
  protocol_providers = local.external_proxy_provider_ids
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
    "kubernetes_ingress_class_name"  = "external"
    "kubernetes_disabled_components" = []
    "kubernetes_ingress_annotations" = {
      "external-dns.alpha.kubernetes.io/is-public" : "true"
      "external-dns.alpha.kubernetes.io/target" : "external.${local.cluster_domain}"
      "nginx.ingress.kubernetes.io/proxy-buffers" : "8 16k"
      "nginx.ingress.kubernetes.io/proxy-busy-buffers-size" : "32k"
    }
    "kubernetes_ingress_secret_name" = "56kbps-io-production-tls"
  })
}
