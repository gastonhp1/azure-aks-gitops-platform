output "client_id" {
  description = "Goes into the azure.workload.identity/client-id service account annotation."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "principal_id" {
  value = azurerm_user_assigned_identity.this.principal_id
}
