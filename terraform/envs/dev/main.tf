terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.50"
    }
  }

  # Created once by terraform/bootstrap. Auth is Entra ID (no storage keys);
  # in CI it uses the GitHub OIDC token (ARM_USE_OIDC=true).
  backend "azurerm" {
    resource_group_name = "rg-tfstate"
    container_name      = "tfstate"
    key                 = "platform/dev.tfstate"
    use_azuread_auth    = true
    # storage_account_name is passed with -backend-config so the globally
    # unique account name stays out of the repo (see Makefile).
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  storage_use_azuread = true
}

module "platform" {
  source = "../../stacks/platform"

  environment            = "dev"
  location               = var.location
  unique_suffix          = var.unique_suffix
  admin_group_object_ids = var.admin_group_object_ids

  network = {
    address_space  = "10.10.0.0/16"
    aks_nodes_cidr = "10.10.0.0/22"
  }

  acr_sku = "Basic"

  # Cheapest sane setup: Free control plane, a single small autoscaled pool,
  # no zones, no Container Insights (Prometheus/Grafana run in-cluster instead).
  aks = {
    sku_tier           = "Free"
    zones              = []
    system_vm_size     = "Standard_D2ads_v5"
    system_min         = 1
    system_max         = 3
    user_pool_enabled  = false
    container_insights = false
  }

  tags = { cost-center = "portfolio", owner = "gastonhp1" }
}
