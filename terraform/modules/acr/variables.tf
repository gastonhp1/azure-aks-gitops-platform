variable "name" {
  description = "Globally unique registry name, alphanumeric only."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.name))
    error_message = "ACR name must be 5-50 alphanumeric characters."
  }
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku" {
  description = "Basic | Standard | Premium. Premium adds retention policies, geo-replication and private endpoints."
  type        = string
  default     = "Basic"
}

variable "untagged_retention_days" {
  type    = number
  default = 7
}

variable "push_principal_ids" {
  description = "Object IDs (e.g. the GitHub Actions OIDC service principal) allowed to push."
  type        = list(string)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
