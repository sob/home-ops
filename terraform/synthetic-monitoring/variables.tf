variable "domain" {
  description = "Domain name for tests (defaults to 1Password secret if not provided)"
  type        = string
  default     = null  # When null, pulls from 1Password item
}

variable "k6_version" {
  description = "k6 Docker image version"
  type        = string
  default     = "latest"
}

variable "prometheus_remote_write_url" {
  description = "Prometheus remote write URL for metrics"
  type        = string
  default     = "http://kube-prometheus-stack-prometheus.observability.svc.cluster.local:9090/api/v1/write"
}

variable "k6_tests" {
  description = "Map of k6 test configurations (overrides defaults from tests.tf)"
  type = map(object({
    script   = string
    schedule = string # Cron schedule, empty string to disable scheduled runs
    env_vars = map(string)
    secret_env_vars = map(object({
      secret_name = string
      secret_key  = string
    }))
    resources = object({
      memory_request = string
      memory_limit   = string
      cpu_request    = string
      cpu_limit      = string
    })
  }))
  default = null
}

variable "onepassword_account" {
  description = "1Password account (from TF_VAR_onepassword_account)"
  type        = string
  default     = null
}

variable "onepassword_vault" {
  description = "1Password vault name"
  type        = string
  default     = "STONEHEDGES"
}

variable "onepassword_item" {
  description = "1Password item name for k6 configuration"
  type        = string
  default     = "k6"
}

variable "onepassword_grafana_item" {
  description = "1Password item name for Grafana Cloud credentials"
  type        = string
  default     = "grafana-cloud"
}