# One-time bootstrap: remote state storage for every environment.
# Runs with local state (chicken-and-egg); the resulting tfstate is tiny and
# can be re-imported if lost. `make bootstrap` runs this.
terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.50"
    }
  }
}

provider "azurerm" {
  features {}
  storage_use_azuread = true
}

variable "location" {
  type    = string
  default = "brazilsouth"
}

variable "storage_account_name" {
  description = "Globally unique, 3-24 lowercase alphanumeric (e.g. sttfstateghp01)."
  type        = string
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "state" {
  name     = "rg-tfstate"
  location = var.location
  tags     = { managed-by = "terraform", purpose = "terraform-state" }
}

resource "azurerm_storage_account" "state" {
  name                            = var.storage_account_name
  resource_group_name             = azurerm_resource_group.state.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false # Entra ID auth only
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = azurerm_resource_group.state.tags
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# Whoever runs the bootstrap can read/write state with their Entra identity.
resource "azurerm_role_assignment" "state_owner" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_management_lock" "state" {
  name       = "do-not-delete-tfstate"
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Holds Terraform state for every environment."
}

output "storage_account_name" {
  value = azurerm_storage_account.state.name
}
