variable "location" {
  type    = string
  default = "brazilsouth"
}

variable "unique_suffix" {
  description = "Short suffix to make ACR/Key Vault names globally unique."
  type        = string
}

variable "admin_group_object_ids" {
  type    = list(string)
  default = []
}
