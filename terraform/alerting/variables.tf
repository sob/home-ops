variable "onepassword_account" {
  description = "1Password account URL"
  type        = string

  validation {
    condition     = length(trimspace(var.onepassword_account)) > 0
    error_message = "onepassword_account is empty. .mise.toml derives TF_VAR_onepassword_account from `op account list` with a 5s timeout, and leaves it empty if 1Password is locked or slow. Unlock 1Password (or run `op signin`) and re-enter the directory, set TF_VAR_onepassword_account yourself, or pin it in a git-ignored .mise.local.toml."
  }
}

variable "prometheus_datasource_uid" {
  description = "UID of the Prometheus datasource in Grafana"
  type        = string
  default     = "grafanacloud-prom"
}