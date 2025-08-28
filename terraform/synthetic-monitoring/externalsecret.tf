# ExternalSecret for API keys needed by synthetic monitoring tests
resource "kubernetes_manifest" "synthetic_monitoring_secrets" {
  manifest = {
    apiVersion = "external-secrets.io/v1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "synthetic-monitoring-secrets"
      namespace = data.kubernetes_namespace.observability.metadata[0].name
    }
    spec = {
      secretStoreRef = {
        name = "onepassword-connect"
        kind = "ClusterSecretStore"
      }
      target = {
        name = "synthetic-monitoring-secrets"
        template = {
          engineVersion = "v2"
          data = {
            SONARR_API_KEY  = "{{ .sonarr_api_key }}"
            RADARR_API_KEY  = "{{ .radarr_api_key }}"
            LIDARR_API_KEY  = "{{ .lidarr_api_key }}"
            READARR_API_KEY = "{{ .readarr_api_key }}"
            PROWLARR_API_KEY = "{{ .prowlarr_api_key }}"
          }
        }
      }
      dataFrom = []
      data = [
        {
          secretKey = "sonarr_api_key"
          remoteRef = {
            key      = "sonarr"
            property = "SONARR_API_KEY"
          }
        },
        {
          secretKey = "radarr_api_key"
          remoteRef = {
            key      = "radarr"
            property = "RADARR_API_KEY"
          }
        },
        {
          secretKey = "lidarr_api_key"
          remoteRef = {
            key      = "lidarr"
            property = "LIDARR_API_KEY"
          }
        },
        {
          secretKey = "readarr_api_key"
          remoteRef = {
            key      = "readarr"
            property = "READARR_API_KEY"
          }
        },
        {
          secretKey = "prowlarr_api_key"
          remoteRef = {
            key      = "prowlarr"
            property = "PROWLARR_API_KEY"
          }
        }
      ]
    }
  }
}