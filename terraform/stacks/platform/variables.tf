variable "project" {
  description = "Short project name used in every resource name."
  type        = string
  default     = "platform"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "location" {
  type    = string
  default = "brazilsouth"
}

variable "unique_suffix" {
  description = "Short random-ish suffix so ACR/Key Vault names are globally unique (e.g. initials + 2 digits)."
  type        = string
}

variable "admin_group_object_ids" {
  description = "Entra ID group(s) with cluster-admin and Key Vault Secrets Officer."
  type        = list(string)
  default     = []
}

variable "github_owner" {
  type    = string
  default = "gastonhp1"
}

variable "github_ci_repos" {
  description = "Repos whose GitHub Actions jobs may push images to ACR."
  type        = list(string)
  default     = ["secure-cicd-golden-path"]
}

variable "network" {
  type = object({
    address_space  = string
    aks_nodes_cidr = string
  })
}

variable "acr_sku" {
  type    = string
  default = "Basic"
}

variable "keyvault_purge_protection" {
  type    = bool
  default = false
}

variable "aks" {
  type = object({
    kubernetes_version = optional(string)
    sku_tier           = string
    zones              = list(string)
    system_vm_size     = string
    system_min         = number
    system_max         = number
    user_pool_enabled  = bool
    user_vm_size       = optional(string, "Standard_D4ads_v5")
    user_min           = optional(number, 1)
    user_max           = optional(number, 3)
    user_pool_spot     = optional(bool, false)
    container_insights = bool
  })
}

variable "tags" {
  type    = map(string)
  default = {}
}
