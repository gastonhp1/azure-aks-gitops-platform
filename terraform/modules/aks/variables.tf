variable "name" {
  description = "Base name (e.g. platform-dev)."
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tenant_id" {
  description = "Entra ID tenant used for cluster authentication."
  type        = string
}

variable "admin_group_object_ids" {
  description = "Entra ID groups that get cluster-admin through Azure RBAC."
  type        = list(string)
  default     = []
}

variable "kubernetes_version" {
  description = "AKS version. null = latest default version in the region."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Free (no uptime SLA) or Standard (financially backed SLA)."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard or Premium."
  }
}

variable "automatic_upgrade_channel" {
  type    = string
  default = "patch"
}

variable "nodes_subnet_id" {
  type = string
}

variable "acr_id" {
  description = "ACR the kubelet identity is allowed to pull from."
  type        = string
}

variable "zones" {
  description = "Availability zones for node pools. Empty list for non-zonal."
  type        = list(string)
  default     = []
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_D2ads_v5"
}

variable "system_node_min_count" {
  type    = number
  default = 1
}

variable "system_node_max_count" {
  type    = number
  default = 3
}

variable "system_node_os_disk_gb" {
  description = "Must fit in the VM temp disk with Ephemeral OS (D2ads_v5 = 75 GiB)."
  type        = number
  default     = 64
}

variable "dedicated_system_pool" {
  description = "Taint the system pool so only critical add-ons run there."
  type        = bool
  default     = false
}

variable "user_pool_enabled" {
  type    = bool
  default = false
}

variable "user_node_vm_size" {
  type    = string
  default = "Standard_D4ads_v5"
}

variable "user_node_min_count" {
  type    = number
  default = 1
}

variable "user_node_max_count" {
  type    = number
  default = 5
}

variable "user_node_os_disk_gb" {
  type    = number
  default = 128
}

variable "user_pool_spot" {
  description = "Run the apps pool on Spot VMs (cheap, evictable)."
  type        = bool
  default     = false
}

variable "pod_cidr" {
  type    = string
  default = "192.168.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "172.16.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "172.16.0.10"
}

variable "enable_container_insights" {
  type    = bool
  default = false
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "log_daily_quota_gb" {
  description = "Hard cap on Log Analytics ingestion to avoid surprise bills. -1 = unlimited."
  type        = number
  default     = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
