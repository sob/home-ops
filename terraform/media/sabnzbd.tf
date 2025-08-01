module "sabnzbd" {
  source = "./modules/sabnzbd"

  url     = "https://sab.56kbps.io"
  api_key = module.secrets.items["sabnzbd"].SABNZBD_API_KEY

  download_dir = "/media/Downloads/sabnzbd/incomplete"
  complete_dir = "/media/Downloads/sabnzbd/complete"

  servers = {
    giganews = {
      host        = "news.giganews.com"
      port        = 563
      username    = module.secrets.items["sabnzbd"].GIGANEWS_USERNAME
      password    = module.secrets.items["sabnzbd"].GIGANEWS_PASSWORD
      connections = 8
      timeout     = 60
      ssl         = true
      enable      = true
      priority    = 0
    }
  }

  categories = {
    movies = {
      priority = -100
      pp       = ""
      script   = "Default"
      dir      = ""
    }
    tv = {
      priority = -100
      pp       = ""
      script   = "Default"
      dir      = ""
    }
    audio = {
      priority = -100
      pp       = ""
      script   = "Default"
      dir      = ""
    }
    books = {
      priority = -100
      pp       = ""
      script   = "Default"
      dir      = ""
    }
    software = {
      priority = -100
      pp       = ""
      script   = "Default"
      dir      = ""
    }
  }

  general_settings = {
    host                  = "0.0.0.0"
    port                  = 80
    bandwidth_max         = "1024M"
    cache_limit          = "1G"
    auto_disconnect      = true
    par_option           = ""
    direct_unpack        = true
    direct_unpack_threads = 3
    pause_on_post_processing = false
    ipv6_servers         = false  # Disabled due to giganews not supporting IPv6
    ipv6_hosting         = false
    check_new_rel        = true
    host_whitelist = [
      "sabnzbd",
      "sabnzbd.default",
      "sabnzbd.default.svc",
      "sabnzbd.default.svc.cluster",
      "sabnzbd.default.svc.cluster.local",
      "sab.${module.secrets.items["cluster-secrets"].SECRET_DOMAIN}"
    ]
  }

  switches = {
    quota_size       = ""
    quota_resume     = true
    quota_period     = "m"
    pre_check        = false
    pause_on_post    = false
    new_nzb_on_failure = true
    propagation_delay = 0
    top_only         = false
    safe_postproc    = true
    no_dupes         = 0
    replace_illegal  = true
    replace_dots     = false
    replace_spaces   = false
    auto_sort        = false
    direct_unpack    = true
    ignore_samples   = true
    deobfuscate_final_filenames = true
  }
}
