variable "name" {
  description = "Globally unique Key Vault name (3-24 chars)."
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "purge_protection_enabled" {
  description = "Recommended in prod. Note: once enabled it cannot be turned off."
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  type    = number
  default = 7
}

variable "allowed_ip_ranges" {
  description = "If set, the vault denies public traffic except from these CIDRs."
  type        = list(string)
  default     = []
}

variable "secrets_officer_principal_ids" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
