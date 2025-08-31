# Test configurations
locals {
  # Use provided domain or fallback to 1Password secret
  test_domain = var.domain != null ? var.domain : nonsensitive(module.secrets.items[var.onepassword_item].DOMAIN)

  # Default values for tests
  default_resources = {
    memory_request = "64Mi"
    memory_limit   = "128Mi"
    cpu_request    = "50m"
    cpu_limit      = "200m"
  }

  default_schedule = "*/5 * * * *"  # Every 5 minutes by default

  default_secret_env_vars = {}  # No secrets by default

  # Base test configurations
  base_test_configs = {
    plex-internal = {
      script   = file("${path.module}/tests/plex-internal.js")
      schedule = "*/5 * * * *" # Every 5 minutes - more frequent for critical service
      env_vars = {
        DOMAIN = local.test_domain
        PLEX_LB_IP = "10.1.100.204"  # Plex LoadBalancer IP
      }
      resources = {
        memory_request = "128Mi"  # Override: more memory for API tests
        memory_limit   = "256Mi"
        cpu_request    = "100m"
        cpu_limit      = "500m"
      }
    }

    plex-external = {
      script   = file("${path.module}/tests/plex-external.js")
      env_vars = {
        DOMAIN = local.test_domain
      }
    }

    jellyseerr = {
      script   = file("${path.module}/tests/base-media.js")
      env_vars = {
        SERVICE_NAME = "jellyseerr"
        SERVICE_URL = "https://jellyseerr.${local.test_domain}"
        API_ENDPOINT = "/api/v1/status"
        HEALTH_ENDPOINT = "/"
        CHECK_STRING = "version"
        SLEEP_DURATION = "10"
      }
    }

    overseerr = {
      script   = file("${path.module}/tests/base-media.js")
      env_vars = {
        SERVICE_NAME = "overseerr"
        SERVICE_URL = "https://requests.${local.test_domain}"
        API_ENDPOINT = "/api/v1/status"
        HEALTH_ENDPOINT = "/"
        CHECK_STRING = "version"
        SLEEP_DURATION = "10"
      }
    }

    sonarr = {
      script   = file("${path.module}/tests/base-media.js")
      env_vars = {
        SERVICE_NAME = "sonarr"
        SERVICE_URL = "https://sonarr.${local.test_domain}"
        API_ENDPOINT = "/api/v3/system/status"
        HEALTH_ENDPOINT = "none"  # Skip health check - requires auth
        CHECK_STRING = "version"
        SLEEP_DURATION = "10"
      }
      secret_env_vars = {
        API_KEY = {
          secret_name = "synthetic-monitoring-secrets"
          secret_key  = "SONARR_API_KEY"
        }
      }
    }

    radarr = {
      script   = file("${path.module}/tests/base-media.js")
      env_vars = {
        SERVICE_NAME = "radarr"
        SERVICE_URL = "https://radarr.${local.test_domain}"
        API_ENDPOINT = "/api/v3/system/status"
        HEALTH_ENDPOINT = "none"  # Skip health check - requires auth
        CHECK_STRING = "version"
        SLEEP_DURATION = "10"
      }
      secret_env_vars = {
        API_KEY = {
          secret_name = "synthetic-monitoring-secrets"
          secret_key  = "RADARR_API_KEY"
        }
      }
    }

    lidarr = {
      script   = file("${path.module}/tests/base-media.js")
      env_vars = {
        SERVICE_NAME = "lidarr"
        SERVICE_URL = "https://lidarr.${local.test_domain}"
        API_ENDPOINT = "/api/v1/system/status"
        HEALTH_ENDPOINT = "none"  # Skip health check - requires auth
        CHECK_STRING = "version"
        SLEEP_DURATION = "10"
      }
      secret_env_vars = {
        API_KEY = {
          secret_name = "synthetic-monitoring-secrets"
          secret_key  = "LIDARR_API_KEY"
        }
      }
    }

    readarr = {
      script   = file("${path.module}/tests/base-media.js")
      env_vars = {
        SERVICE_NAME = "readarr"
        SERVICE_URL = "https://readarr.${local.test_domain}"
        API_ENDPOINT = "/api/v1/system/status"
        HEALTH_ENDPOINT = "none"  # Skip health check - requires auth
        CHECK_STRING = "version"
        SLEEP_DURATION = "10"
      }
      secret_env_vars = {
        API_KEY = {
          secret_name = "synthetic-monitoring-secrets"
          secret_key  = "READARR_API_KEY"
        }
      }
    }

    prowlarr = {
      script   = file("${path.module}/tests/base-media.js")
      env_vars = {
        SERVICE_NAME = "prowlarr"
        SERVICE_URL = "https://prowlarr.${local.test_domain}"
        API_ENDPOINT = "/api/v1/system/status"
        HEALTH_ENDPOINT = "none"  # Skip health check - requires auth
        CHECK_STRING = "version"
        SLEEP_DURATION = "10"
      }
      secret_env_vars = {
        API_KEY = {
          secret_name = "synthetic-monitoring-secrets"
          secret_key  = "PROWLARR_API_KEY"
        }
      }
    }

    jellyfin = {
      script   = file("${path.module}/tests/base-media.js")
      env_vars = {
        SERVICE_NAME = "jellyfin"
        SERVICE_URL = "https://jellyfin.${local.test_domain}"
        API_ENDPOINT = "/System/Info/Public"
        HEALTH_ENDPOINT = "/"
        CHECK_STRING = "Jellyfin"
        SLEEP_DURATION = "10"
      }
    }

    sabnzbd = {
      script   = file("${path.module}/tests/base-media.js")
      env_vars = {
        SERVICE_NAME = "sabnzbd"
        SERVICE_URL = "https://sab.${local.test_domain}"  # SABnzbd uses sab subdomain
        API_ENDPOINT = "none"  # SABnzbd API requires API key
        HEALTH_ENDPOINT = "/"
        CHECK_STRING = "SABnzbd"
        SLEEP_DURATION = "10"
      }
    }

    tautulli = {
      script   = file("${path.module}/tests/base-media.js")
      env_vars = {
        SERVICE_NAME = "tautulli"
        SERVICE_URL = "https://tautulli.${local.test_domain}"
        API_ENDPOINT = "none"  # Tautulli API requires API key
        HEALTH_ENDPOINT = "/"
        CHECK_STRING = "Tautulli"
        SLEEP_DURATION = "10"
      }
    }
  }

  # Merge base configs with defaults
  k6_test_configs = {
    for name, config in local.base_test_configs : name => merge(
      {
        # Set defaults first
        schedule = local.default_schedule
        secret_env_vars = local.default_secret_env_vars
        resources = local.default_resources
      },
      config,  # Config overrides defaults
      {
        # Ensure resources are properly merged (defaults + overrides)
        resources = merge(local.default_resources, try(config.resources, {}))
      }
    )
  }
}
