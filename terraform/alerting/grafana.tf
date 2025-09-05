provider "grafana" {
  url          = local.grafana_url
  auth         = local.grafana_auth
  http_headers = {
    "Content-Type" = "application/json"
  }
  retries      = 3
  retry_wait   = 5
}