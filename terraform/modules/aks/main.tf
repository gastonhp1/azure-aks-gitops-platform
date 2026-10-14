resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${var.name}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# With a custom VNet the control plane identity must be able to manage the
# node subnet (load balancers, NICs). Scoped to the subnet, not the VNet.
resource "azurerm_role_assignment" "control_plane_network" {
  scope                = var.nodes_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_log_analytics_workspace" "this" {
  count               = var.enable_container_insights ? 1 : 0
  name                = "log-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  daily_quota_gb      = var.log_daily_quota_gb
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.name}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  tags                = var.tags

  # Identity & access: no local admin kubeconfig, Entra ID + Azure RBAC only.
  local_account_disabled            = true
  role_based_access_control_enabled = true
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    tenant_id              = var.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
  }

  # Workload Identity: pods get Entra tokens via federated credentials,
  # so no client secrets ever live in the cluster.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = "NodeImage"

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "03:00"
    utc_offset  = "-03:00"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    vnet_subnet_id               = var.nodes_subnet_id
    zones                        = var.zones
    auto_scaling_enabled         = true
    min_count                    = var.system_node_min_count
    max_count                    = var.system_node_max_count
    max_pods                     = 110
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = var.system_node_os_disk_gb
    only_critical_addons_enabled = var.dedicated_system_pool
    temporary_name_for_rotation  = "systemtmp"

    upgrade_settings {
      max_surge = "33%"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  dynamic "oms_agent" {
    for_each = var.enable_container_insights ? [1] : []
    content {
      log_analytics_workspace_id      = azurerm_log_analytics_workspace.this[0].id
      msi_auth_for_monitoring_enabled = true
    }
  }

  depends_on = [azurerm_role_assignment.control_plane_network]

  lifecycle {
    # The autoscaler owns the current node count.
    ignore_changes = [default_node_pool[0].node_count]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                 = var.user_pool_enabled ? 1 : 0
  name                  = "apps"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_node_vm_size
  vnet_subnet_id        = var.nodes_subnet_id
  zones                 = var.zones
  mode                  = "User"
  auto_scaling_enabled  = true
  min_count             = var.user_node_min_count
  max_count             = var.user_node_max_count
  os_disk_type          = "Ephemeral"
  os_disk_size_gb       = var.user_node_os_disk_gb
  priority              = var.user_pool_spot ? "Spot" : "Regular"
  eviction_policy       = var.user_pool_spot ? "Delete" : null
  spot_max_price        = var.user_pool_spot ? -1 : null
  node_labels           = { "workload" = "apps" }
  tags                  = var.tags

  lifecycle {
    ignore_changes = [node_count]
  }
}

# Let the kubelet pull images from ACR without image pull secrets.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
