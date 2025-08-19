# Consolidated folder structure - simplified from 7 to 4 folders

resource "grafana_folder" "infrastructure" {
  title = "Infrastructure & Platform"
}

resource "grafana_folder" "storage" {
  title = "Storage"
}

resource "grafana_folder" "applications" {
  title = "Applications"
}

resource "grafana_folder" "monitoring" {
  title = "Monitoring & Observability"
}

# Folder mapping for existing resources:
# - infrastructure: nodes, power, prometheus connectivity, flux, external-secrets
# - storage: smartctl, ceph, volsync
# - applications: all media services, critical services, cert-manager
# - monitoring: response times, infrastructure metrics