landingzone = {
  backend_type        = "azurerm"
  global_settings_key = "launchpad"
  level               = "level0"
  key                 = "launchpad"
  launchpad = {
    level   = "current"
    tfstate = "launchpad.tfstate"
  }
}

# Default region. When not set to a resource it will use that value
default_region = "region1"

regions = {
  region1 = "westeurope"
  region2 = "northeurope"
}

enable = {
  bastion_hosts    = false
  virtual_machines = false
}

# all resources deployed will inherit tags from the parent resource group
inherit_tags = true

launchpad_key_names = {
  azuread_app            = "caf_launchpad_level0"
  keyvault_client_secret = "aadapp-caf-launchpad-level0"
  tfstates = [
    "level0",
    "level1",
  ]
}

resource_groups = {
  level0 = {
    name = "launchpad-level0"
    tags = {
      level = "level0"
    }
  }
  level1 = {
    name = "launchpad-level1"
    tags = {
      level = "level1"
    }
  }
}
