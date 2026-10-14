# A user-assigned managed identity that trusts one or more external OIDC
# subjects. Used for two things in this platform:
#   - Kubernetes Workload Identity  (issuer = AKS OIDC issuer,
#     subject = system:serviceaccount:<ns>:<sa>)
#   - GitHub Actions OIDC           (issuer = token.actions.githubusercontent.com,
#     subject = repo:<owner>/<repo>:environment:<env>)
# Either way, no client secret is ever created.
resource "azurerm_user_assigned_identity" "this" {
  name                = "id-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "this" {
  for_each            = toset(var.subjects)
  name                = substr(replace(lower(each.value), "/[^a-z0-9-]/", "-"), 0, 120)
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.this.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.issuer
  subject             = each.value
}

resource "azurerm_role_assignment" "this" {
  for_each             = { for r in var.role_assignments : "${r.role}|${r.scope}" => r }
  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}
