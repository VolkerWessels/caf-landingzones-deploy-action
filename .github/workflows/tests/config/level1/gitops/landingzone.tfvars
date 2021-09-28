landingzone = {
  backend_type        = "azurerm"
  global_settings_key = "launchpad"
  level               = "level1"
  key                 = "gitops"
  tfstates = {
    gitops = {
      level   = "current"
      tfstate = "gitops.tfstate"
    }
    launchpad = {
      level   = "lower"
      tfstate = "launchpad.tfstate"
    }
  }
}


# Initial resource created to get a valid state in the backend
resource_groups = {
  gitops = {
    name = "gitops"
  }
}
