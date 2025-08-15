module "secrets" {
  source = "./modules/onepassword"
  vault  = "STONEHEDGES"
  items  = ["grafana-cloud", "alertmanager"]
}