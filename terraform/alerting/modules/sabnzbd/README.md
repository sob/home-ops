# SABnzbd Terraform Module

This module manages SABnzbd configuration using the SABnzbd REST API.

## Features

- Configure general settings (bandwidth, cache, direct unpack, etc.)
- Manage news servers
- Configure categories for different media types
- Set download and complete directories
- Configure various switches and options
- IPv6 support configuration

## Requirements

- SABnzbd instance running and accessible
- SABnzbd API key
- Terraform >= 1.0

## Usage

```hcl
module "sabnzbd" {
  source = "./modules/sabnzbd"

  url     = "http://sabnzbd.default.svc.cluster.local"
  api_key = module.secrets.items["sabnzbd"].SABNZBD_API_KEY

  download_dir = "/media/Downloads/sabnzbd/incomplete"
  complete_dir = "/media/Downloads/sabnzbd/complete"

  servers = {
    giganews = {
      host        = "news.giganews.com"
      port        = 563
      username    = "myusername"
      password    = "mypassword"
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
    }
    audio = {
      priority = -100
    }
    books = {
      priority = -100
    }
  }

  general_settings = {
    bandwidth_max         = "1024M"
    cache_limit          = "1G"
    direct_unpack        = true
    direct_unpack_threads = 3
    ipv6_servers         = false
    ipv6_hosting         = false
    host_whitelist = [
      "sabnzbd.${var.domain}",
      "sabnzbd.default.svc.cluster.local"
    ]
  }

  switches = {
    pre_check        = false
    pause_on_post    = false
    safe_postproc    = true
    replace_illegal  = true
    replace_dots     = false
    replace_spaces   = false
    direct_unpack    = true
    ignore_samples   = true
    deobfuscate_final_filenames = true
  }
}
```

## Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| url | The URL of the SABnzbd instance | string | - |
| api_key | The API key for SABnzbd | string | - |
| download_dir | Path for incomplete downloads | string | "/media/Downloads/sabnzbd/incomplete" |
| complete_dir | Path for completed downloads | string | "/media/Downloads/sabnzbd/complete" |
| categories | Categories configuration | map(object) | See variables.tf |
| servers | News server configuration | map(object) | - |
| general_settings | General SABnzbd settings | object | See variables.tf |
| switches | SABnzbd switches/toggles | object | See variables.tf |
| scheduling | Scheduling configuration | object | {} |

## Outputs

| Name | Description |
|------|-------------|
| api_key | The API key for SABnzbd (sensitive) |
| url | The URL of the SABnzbd instance |
| download_dir | Path for incomplete downloads |
| complete_dir | Path for completed downloads |
| categories | Configured categories |
| general_settings | General SABnzbd settings |

## Notes

- This module uses the `null_resource` with local-exec provisioners to interact with the SABnzbd API
- Changes are applied immediately and the configuration is saved automatically
- The module is idempotent - running it multiple times with the same configuration will not cause issues
- Server passwords are marked as sensitive in the variables

## Limitations

- The module currently uses curl commands via local-exec, which requires curl to be installed
- Some advanced SABnzbd settings may not be exposed through this module
- The module doesn't support reading the current configuration from SABnzbd