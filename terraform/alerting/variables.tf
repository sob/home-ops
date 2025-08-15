variable "onepassword_account" {
  description = "1Password account URL"
  type        = string
}

variable "prometheus_datasource_uid" {
  description = "UID of the Prometheus datasource in Grafana"
  type        = string
  default     = "grafanacloud-prom"
}