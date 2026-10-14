resource "azurerm_container_registry" "this" {
  # ACR names: 5-50 alphanumeric chars, globally unique.
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  admin_enabled                 = false
  anonymous_pull_enabled        = false
  public_network_access_enabled = true
  tags                          = var.tags

  dynamic "retention_policy" {
    for_each = var.sku == "Premium" ? [1] : []
    content {
      days    = var.untagged_retention_days
      enabled = true
    }
  }
}

# Identities that push images (CI via OIDC). Pull is granted to the kubelet in the aks module.
resource "azurerm_role_assignment" "push" {
  for_each             = toset(var.push_principal_ids)
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = each.value
}
