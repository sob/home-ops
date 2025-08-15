locals {
  # Define which fields are boolean
  boolean_general_fields = toset([
    "auto_disconnect", "direct_unpack", "pause_on_post_processing",
    "ipv6_servers", "ipv6_hosting", "check_new_rel"
  ])
  
  boolean_switch_fields = toset([
    "quota_resume", "pre_check", "pause_on_post", "new_nzb_on_failure",
    "top_only", "safe_postproc", "replace_illegal", "replace_dots",
    "replace_spaces", "auto_sort", "direct_unpack", "ignore_samples",
    "deobfuscate_final_filenames"
  ])

  # Convert all values to strings for consistent handling
  general_settings = merge(
    {
      host           = "0.0.0.0"
      port           = "80"
      bandwidth_max  = "1024M"
      cache_limit    = "1G"
      auto_disconnect = "1"
      par_option     = ""
      direct_unpack  = "1"
      direct_unpack_threads = "3"
      pause_on_post_processing = "0"
      ipv6_servers   = "0"
      ipv6_hosting   = "0"
      check_new_rel  = "1"
      host_whitelist = ""
    },
    {
      for k, v in var.general_settings : k => (
        k == "host_whitelist" ? join(", ", v) :
        contains(local.boolean_general_fields, k) ? (v ? "1" : "0") :
        tostring(v)
      )
    }
  )

  switches = merge(
    {
      quota_size       = ""
      quota_resume     = "1"
      quota_period     = "m"
      pre_check        = "0"
      pause_on_post    = "0"
      new_nzb_on_failure = "1"
      propagation_delay = "0"
      top_only         = "0"
      safe_postproc    = "1"
      no_dupes         = "0"
      replace_illegal  = "1"
      replace_dots     = "0"
      replace_spaces   = "0"
      auto_sort        = "0"
      direct_unpack    = "1"
      ignore_samples   = "0"
      deobfuscate_final_filenames = "1"
    },
    {
      for k, v in var.switches : k => (
        contains(local.boolean_switch_fields, k) ? (v ? "1" : "0") :
        tostring(v)
      )
    }
  )

  # Prepare servers configuration
  servers_config = {
    for k, v in var.servers : k => {
      name        = v.host
      displayname = k
      host        = v.host
      port        = tostring(v.port)
      username    = v.username
      password    = v.password
      connections = tostring(v.connections)
      timeout     = tostring(v.timeout)
      ssl         = v.ssl ? "1" : "0"
      enable      = v.enable ? "1" : "0"
      priority    = tostring(v.priority)
    }
  }

  # Prepare categories configuration
  categories_config = {
    for k, v in var.categories : k => {
      name     = k
      priority = tostring(v.priority)
      pp       = v.pp
      script   = v.script
      dir      = v.dir
    }
  }

  # Complete configuration object
  config = {
    general_settings = local.general_settings
    switches        = local.switches
    servers         = local.servers_config
    categories      = local.categories_config
    download_dir    = var.download_dir
    complete_dir    = var.complete_dir
  }
}

# Configure SABnzbd using a single resource
resource "null_resource" "sabnzbd_configure" {
  triggers = {
    config_hash = sha256(jsonencode({
      general_settings = local.general_settings
      switches        = local.switches
      servers         = nonsensitive(jsonencode(keys(var.servers)))
      categories      = local.categories_config
      download_dir    = var.download_dir
      complete_dir    = var.complete_dir
    }))
  }

  provisioner "local-exec" {
    command = "/bin/bash ${path.module}/scripts/configure.sh"
    
    environment = {
      SABNZBD_API_KEY = var.api_key
      SABNZBD_URL     = var.url
      SABNZBD_CONFIG  = jsonencode(local.config)
    }
  }
}