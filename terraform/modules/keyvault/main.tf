resource "azurerm_key_vault" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = true
  tags                          = var.tags

  network_acls {
    default_action = length(var.allowed_ip_ranges) == 0 ? "Allow" : "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ip_ranges
  }
}

# Humans/pipelines that manage secret values (never Terraform-managed values in state).
resource "azurerm_role_assignment" "secrets_officers" {
  for_each             = toset(var.secrets_officer_principal_ids)
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}
