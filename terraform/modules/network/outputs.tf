output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "aks_nodes_subnet_id" {
  value = azurerm_subnet.aks_nodes.id
}

output "private_endpoints_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}
