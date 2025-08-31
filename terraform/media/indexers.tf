# Prowlarr Indexers Configuration
# Credentials are stored in 1Password in the prowlarr item

# NZBPlanet (Usenet indexer - Platinum tier)
resource "prowlarr_indexer" "nzbplanet" {
  enable         = true
  name           = "NZBPlanet"
  implementation = "Newznab"
  config_contract = "NewznabSettings"
  protocol       = "usenet"
  app_profile_id = 1
  priority       = 25
  
  fields = [
    {
      name = "baseUrl"
      text_value = "https://api.nzbplanet.net"
    },
    {
      name = "apiPath"
      text_value = "/api"
    },
    {
      name = "apiKey"
      sensitive_value = module.secrets.items["prowlarr"].NZBPLANET_API_KEY
    },
    {
      name = "categories"
      set_value = [2000,2010,2020,2030,2040,2045,2050,2060,3000,3010,3020,3030,3040,3050,4000,4010,4020,4030,4040,4045,4050,4060,4070,5000,5010,5020,5030,5040,5045,5050,5060,5070,5080,6000,6010,6020,6030,6040,6050,6060,6070,6080,6090,7000,7010,7020,7030]
    },
    {
      name = "animeCategories"
      set_value = []
    },
    {
      name = "animeStandardFormatSearch"
      bool_value = false
    },
    {
      name = "additionalParameters"
      text_value = ""
    },
    {
      name = "multiLanguages"
      set_value = []
    },
    {
      name = "baseSettings.limitsUnit"
      select_value = "Day"
    },
    {
      name = "baseSettings.grabLimit"
      number_value = 0  # Platinum tier: unlimited downloads
    },
    {
      name = "baseSettings.queryLimit"
      number_value = 20000  # Platinum tier: 20,000 API calls per day
    }
  ]

  tags = []
}

# NZBgeek (Usenet indexer)
resource "prowlarr_indexer" "nzbgeek" {
  enable         = true
  name           = "NZBgeek"
  implementation = "Newznab"
  config_contract = "NewznabSettings"
  protocol       = "usenet"
  app_profile_id = 1
  priority       = 25
  
  fields = [
    {
      name = "baseUrl"
      text_value = "https://api.nzbgeek.info"
    },
    {
      name = "apiPath"
      text_value = "/api"
    },
    {
      name = "apiKey"
      sensitive_value = module.secrets.items["prowlarr"].NZBGEEK_API_KEY
    },
    {
      name = "categories"
      set_value = [2000,2010,2020,2030,2040,2045,2050,2060,3000,3010,3020,3030,3040,3050,4000,4010,4020,4030,4040,4045,4050,4060,4070,5000,5010,5020,5030,5040,5045,5050,5060,5070,5080,6000,6010,6020,6030,6040,6050,6060,6070,6080,6090,7000,7010,7020,7030]
    },
    {
      name = "animeCategories"
      set_value = []
    },
    {
      name = "animeStandardFormatSearch"
      bool_value = false
    },
    {
      name = "additionalParameters"
      text_value = ""
    },
    {
      name = "multiLanguages"
      set_value = []
    },
    {
      name = "baseSettings.limitsUnit"
      select_value = "Day"
    },
    {
      name = "baseSettings.grabLimit"
      number_value = 100
    },
    {
      name = "baseSettings.queryLimit"
      number_value = 100
    }
  ]

  tags = []
}

# NZBFinder (Usenet indexer)
resource "prowlarr_indexer" "nzbfinder" {
  enable         = true
  name           = "NZBFinder"
  implementation = "Newznab"
  config_contract = "NewznabSettings"
  protocol       = "usenet"
  app_profile_id = 1
  priority       = 25
  
  fields = [
    {
      name = "baseUrl"
      text_value = "https://nzbfinder.ws"
    },
    {
      name = "apiPath"
      text_value = "/api"
    },
    {
      name = "apiKey"
      sensitive_value = module.secrets.items["prowlarr"].NZBFINDER_API_KEY
    },
    {
      name = "categories"
      set_value = [2000,2010,2020,2030,2040,2045,2050,2060,3000,3010,3020,3030,3040,3050,4000,4010,4020,4030,4040,4045,4050,4060,4070,5000,5010,5020,5030,5040,5045,5050,5060,5070,5080,6000,6010,6020,6030,6040,6050,6060,6070,6080,6090,7000,7010,7020,7030]
    },
    {
      name = "animeCategories"
      set_value = []
    },
    {
      name = "animeStandardFormatSearch"
      bool_value = false
    },
    {
      name = "additionalParameters"
      text_value = ""
    },
    {
      name = "multiLanguages"
      set_value = []
    },
    {
      name = "baseSettings.limitsUnit"
      select_value = "Day"
    },
    {
      name = "baseSettings.grabLimit"
      number_value = 100
    },
    {
      name = "baseSettings.queryLimit"
      number_value = 100
    }
  ]

  tags = []
}