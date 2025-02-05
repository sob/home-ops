locals {
  cluster_domain   = module.secrets.items["prowlarr"].PROWLARR_URL
}
