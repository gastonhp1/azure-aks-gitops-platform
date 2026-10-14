terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.50"
    }
  }

  backend "azurerm" {
    resource_group_name = "rg-tfstate"
    container_name      = "tfstate"
    key                 = "platform/prod.tfstate"
    use_azuread_auth    = true
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  storage_use_azuread = true
}

module "platform" {
  source = "../../stacks/platform"

  environment            = "prod"
  location               = var.location
  unique_suffix          = var.unique_suffix
  admin_group_object_ids = var.admin_group_object_ids

  network = {
    address_space  = "10.20.0.0/16"
    aks_nodes_cidr = "10.20.0.0/22"
  }

  acr_sku                   = "Standard"
  keyvault_purge_protection = true

  # Production shape: SLA-backed control plane, zone-redundant pools,
  # a tainted system pool and a separate autoscaled apps pool.
  aks = {
    sku_tier           = "Standard"
    zones              = ["1", "2", "3"]
    system_vm_size     = "Standard_D2ads_v5"
    system_min         = 3
    system_max         = 3
    user_pool_enabled  = true
    user_vm_size       = "Standard_D4ads_v5"
    user_min           = 2
    user_max           = 6
    container_insights = true
  }

  tags = { cost-center = "portfolio", owner = "gastonhp1" }
}
