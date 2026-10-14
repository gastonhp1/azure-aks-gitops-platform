variable "name" {
  description = "Base name used for network resources (e.g. platform-dev)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the network."
  type        = string
}

variable "address_space" {
  description = "VNet CIDR."
  type        = string
  default     = "10.10.0.0/16"
}

variable "aks_nodes_cidr" {
  description = "Subnet CIDR for AKS nodes. Pods use an overlay CIDR, so this can stay small."
  type        = string
  default     = "10.10.0.0/22"
}

variable "private_endpoints_cidr" {
  description = "Subnet CIDR reserved for private endpoints (ACR, Key Vault)."
  type        = string
  default     = "10.10.8.0/24"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
