output "cluster_id" {
  value = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  description = "Issuer used by federated identity credentials (Workload Identity)."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.this.node_resource_group
}

output "kubelet_object_id" {
  value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}
