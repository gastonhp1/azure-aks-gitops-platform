output "resource_group" {
  value = azurerm_resource_group.this.name
}

output "cluster_name" {
  value = module.aks.cluster_name
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "key_vault_uri" {
  value = module.keyvault.vault_uri
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

# These client IDs are not secrets: they are copied into GitOps values
# (service account annotations) and GitHub repository variables.
output "external_secrets_client_id" {
  value = module.external_secrets_identity.client_id
}

output "cloudsweep_client_id" {
  value = module.cloudsweep_identity.client_id
}

output "github_ci_client_id" {
  description = "Set as AZURE_CLIENT_ID in the secure-cicd-golden-path repo environment."
  value       = module.github_ci_identity.client_id
}

output "kubeconfig_command" {
  value = "az aks get-credentials -g ${azurerm_resource_group.this.name} -n ${module.aks.cluster_name} && kubelogin convert-kubeconfig -l azurecli"
}
