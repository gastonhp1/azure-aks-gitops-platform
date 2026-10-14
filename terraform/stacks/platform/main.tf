data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

locals {
  name = "${var.project}-${var.environment}"
  # Globally unique, alphanumeric-only names (ACR, Key Vault).
  compact_name = substr(replace("${var.project}${var.environment}${var.unique_suffix}", "-", ""), 0, 20)

  tags = merge(var.tags, {
    project     = var.project
    environment = var.environment
    managed-by  = "terraform"
    repo        = "azure-aks-gitops-platform"
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

module "network" {
  source              = "../../modules/network"
  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.network.address_space
  aks_nodes_cidr      = var.network.aks_nodes_cidr
  tags                = local.tags
}

module "acr" {
  source              = "../../modules/acr"
  name                = "acr${local.compact_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.acr_sku
  push_principal_ids  = [module.github_ci_identity.principal_id]
  tags                = local.tags
}

module "keyvault" {
  source                        = "../../modules/keyvault"
  name                          = "kv-${local.compact_name}"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.this.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled      = var.keyvault_purge_protection
  secrets_officer_principal_ids = var.admin_group_object_ids
  tags                          = local.tags
}

module "aks" {
  source                    = "../../modules/aks"
  name                      = local.name
  location                  = var.location
  resource_group_name       = azurerm_resource_group.this.name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  admin_group_object_ids    = var.admin_group_object_ids
  kubernetes_version        = var.aks.kubernetes_version
  sku_tier                  = var.aks.sku_tier
  zones                     = var.aks.zones
  nodes_subnet_id           = module.network.aks_nodes_subnet_id
  acr_id                    = module.acr.id
  system_node_vm_size       = var.aks.system_vm_size
  system_node_min_count     = var.aks.system_min
  system_node_max_count     = var.aks.system_max
  dedicated_system_pool     = var.aks.user_pool_enabled
  user_pool_enabled         = var.aks.user_pool_enabled
  user_node_vm_size         = var.aks.user_vm_size
  user_node_min_count       = var.aks.user_min
  user_node_max_count       = var.aks.user_max
  user_pool_spot            = var.aks.user_pool_spot
  enable_container_insights = var.aks.container_insights
  tags                      = local.tags
}

# --- Identities -------------------------------------------------------------

# External Secrets Operator reads secrets from Key Vault (read-only).
module "external_secrets_identity" {
  source              = "../../modules/federated-identity"
  name                = "${local.name}-external-secrets"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  issuer              = module.aks.oidc_issuer_url
  subjects            = ["system:serviceaccount:external-secrets:external-secrets"]

  role_assignments = [
    { role = "Key Vault Secrets User", scope = module.keyvault.id },
  ]
  tags = local.tags
}

# cloudsweep (FinOps CronJob) needs read-only visibility over the subscription.
module "cloudsweep_identity" {
  source              = "../../modules/federated-identity"
  name                = "${local.name}-cloudsweep"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  issuer              = module.aks.oidc_issuer_url
  subjects            = ["system:serviceaccount:cloudsweep:cloudsweep"]

  role_assignments = [
    { role = "Reader", scope = data.azurerm_subscription.current.id },
  ]
  tags = local.tags
}

# GitHub Actions (secure-cicd-golden-path) pushes signed images to ACR via OIDC.
# Bound to a GitHub *environment*, so only jobs gated by that environment can push.
module "github_ci_identity" {
  source              = "../../modules/federated-identity"
  name                = "${local.name}-github-ci"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  issuer              = "https://token.actions.githubusercontent.com"

  subjects = [
    for repo in var.github_ci_repos : "repo:${var.github_owner}/${repo}:environment:${var.environment}"
  ]
  tags = local.tags
}
