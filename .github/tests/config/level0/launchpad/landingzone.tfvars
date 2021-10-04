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

# Store output attributes into keyvault secret
# Those values are used by the rover to connect the current remote state and
# identity the lower level
dynamic_keyvault_secrets = {
  level0 = {
    subscription_id = {
      output_key    = "client_config"
      attribute_key = "subscription_id"
      secret_name   = "subscription-id"
    }
    tenant_id = {
      output_key    = "client_config"
      attribute_key = "tenant_id"
      secret_name   = "tenant-id"
    }
  }
  level1 = {
    lower_stg = {
      output_key    = "storage_accounts"
      resource_key  = "level0"
      attribute_key = "name"
      secret_name   = "lower-storage-account-name"
    }
    lower_rg = {
      output_key    = "resource_groups"
      resource_key  = "level0"
      attribute_key = "name"
      secret_name   = "lower-resource-group-name"
    }
    subscription_id = {
      output_key    = "client_config"
      attribute_key = "subscription_id"
      secret_name   = "subscription-id"
    }
    tenant_id = {
      output_key    = "client_config"
      attribute_key = "tenant_id"
      secret_name   = "tenant-id"
    }
  }
}

role_mapping = {
  built_in_role_mapping = {
    storage_accounts = {
      level0 = {
        "Storage Blob Data Contributor" = {
          logged_in = {
            keys = ["user"]
          }
        }
      }
      level1 = {
        "Storage Blob Data Contributor" = {
          logged_in = {
            keys = ["user"]
          }
        }
      }
    }
  }
}

keyvaults = {
  level0 = {
    name                = "level0"
    resource_group_key  = "level0"
    sku_name            = "standard"
    soft_delete_enabled = true
    tags = {
      tfstate     = "level0"
      environment = "action"
    }

    creation_policies = {
      logged_in_user = {
        # if the key is set to "logged_in_user" add the user running terraform in the keyvault policy
        # More examples in /examples/keyvault
        secret_permissions = ["Set", "Get", "List", "Delete", "Purge", "Recover"]
      }
    }

  }

  level1 = {
    name                = "level1"
    resource_group_key  = "level1"
    sku_name            = "standard"
    soft_delete_enabled = true
    tags = {
      tfstate     = "level1"
      environment = "action"
    }

    creation_policies = {
      logged_in_user = {
        # if the key is set to "logged_in_user" add the user running terraform in the keyvault policy
        # More examples in /examples/keyvault
        secret_permissions = ["Set", "Get", "List", "Delete", "Purge", "Recover"]
      }
    }
  }
}

storage_accounts = {
  level0 = {
    name                     = "level0"
    resource_group_key       = "level0"
    account_kind             = "BlobStorage"
    account_tier             = "Standard"
    account_replication_type = "RAGRS"
    tags                     = {
      ## Those tags must never be changed after being set as they are used by the rover to locate the launchpad and the tfstates.
      # Only adjust the environment value at creation time
      tfstate     = "level0"
      environment = "action"
      launchpad   = "launchpad"
      ##
    }
    blob_properties          = {
      versioning_enabled                = true
      container_delete_retention_policy = 7
      delete_retention_policy           = 7
    }
    containers               = {
      tfstate = {
        name = "tfstate"
      }
    }
  }


  level1 = {
    name                     = "level1"
    resource_group_key       = "level1"
    account_kind             = "BlobStorage"
    account_tier             = "Standard"
    account_replication_type = "RAGRS"
    tags                     = {
      # Those tags must never be changed while set as they are used by the rover to locate the launchpad and the tfstates.
      tfstate     = "level1"
      environment = "action"
      launchpad   = "launchpad"
    }
    blob_properties          = {
      versioning_enabled                = true
      container_delete_retention_policy = 7
      delete_retention_policy           = 7
    }
    containers               = {
      tfstate = {
        name = "tfstate"
      }
    }
  }
}
