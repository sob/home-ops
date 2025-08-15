variable "url" {
  description = "The URL of the SABnzbd instance"
  type        = string
}

variable "api_key" {
  description = "The API key for SABnzbd"
  type        = string
  sensitive   = false
}

variable "download_dir" {
  description = "Path for incomplete downloads"
  type        = string
  default     = "/media/Downloads/sabnzbd/incomplete"
}

variable "complete_dir" {
  description = "Path for completed downloads"
  type        = string
  default     = "/media/Downloads/sabnzbd/complete"
}

variable "categories" {
  description = "Categories configuration for SABnzbd"
  type = map(object({
    priority = optional(number, -100)
    pp       = optional(string, "")
    script   = optional(string, "Default")
    dir      = optional(string, "")
  }))
  default = {
    movies = {
      priority = -100
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
    software = {
      priority = -100
    }
  }
}

variable "servers" {
  description = "News server configuration"
  type = map(object({
    host        = string
    port        = number
    username    = string
    password    = string
    connections = optional(number, 8)
    timeout     = optional(number, 60)
    ssl         = optional(bool, true)
    enable      = optional(bool, true)
    priority    = optional(number, 0)
  }))
}

variable "general_settings" {
  description = "General SABnzbd settings"
  type = object({
    host           = optional(string, "0.0.0.0")
    port           = optional(number, 80)
    bandwidth_max  = optional(string, "1024M")
    cache_limit    = optional(string, "1G")
    auto_disconnect = optional(bool, true)
    par_option     = optional(string, "")
    direct_unpack  = optional(bool, true)
    direct_unpack_threads = optional(number, 3)
    pause_on_post_processing = optional(bool, false)
    ipv6_servers   = optional(bool, false)
    ipv6_hosting   = optional(bool, false)
    check_new_rel  = optional(bool, true)
    host_whitelist = optional(list(string), [])
  })
  default = {}
}

variable "switches" {
  description = "SABnzbd switches/toggles"
  type = object({
    quota_size       = optional(string, "")
    quota_resume     = optional(bool, true)
    quota_period     = optional(string, "m")
    pre_check        = optional(bool, false)
    pause_on_post    = optional(bool, false)
    new_nzb_on_failure = optional(bool, true)
    propagation_delay = optional(number, 0)
    top_only         = optional(bool, false)
    safe_postproc    = optional(bool, true)
    no_dupes         = optional(number, 0)
    replace_illegal  = optional(bool, true)
    replace_dots     = optional(bool, false)
    replace_spaces   = optional(bool, false)
    auto_sort        = optional(bool, false)
    direct_unpack    = optional(bool, true)
    ignore_samples   = optional(bool, false)
    deobfuscate_final_filenames = optional(bool, true)
  })
  default = {}
}

variable "scheduling" {
  description = "Scheduling configuration"
  type = object({
    sched_converted  = optional(number, 2)
    schedlines       = optional(list(string), [])
  })
  default = {}
}
