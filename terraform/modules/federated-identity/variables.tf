variable "name" {
  description = "Identity name suffix (e.g. external-secrets-dev)."
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "issuer" {
  description = "OIDC issuer URL trusted by this identity."
  type        = string
}

variable "subjects" {
  description = "Exact token subjects allowed to exchange for this identity."
  type        = list(string)

  validation {
    condition     = length(var.subjects) > 0 && length(var.subjects) <= 20
    error_message = "Provide between 1 and 20 subjects (Entra limit per identity)."
  }
}

variable "role_assignments" {
  description = "Least-privilege roles for this identity."

  type = list(object({
    role  = string
    scope = string
  }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
