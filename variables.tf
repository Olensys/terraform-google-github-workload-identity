variable "name" {
  description = "Workload identity pool id. Lowercase letters, digits and hyphens, 4 to 32 characters (the provider limit)."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{4,32}$", var.name))
    error_message = "name must match ^[a-z0-9-]{4,32}$."
  }
}

variable "context" {
  description = "Deployment context used for naming, tagging and environment-dependent defaults."
  type = object({
    organization = string
    environment  = string
    application  = string
    component    = optional(string)
    owner        = string
    cost_center  = string
    extra_tags   = optional(map(string), {})
  })
  validation {
    condition     = contains(["dev", "staging", "prod", "test", "shared"], var.context.environment)
    error_message = "context.environment must be one of dev, staging, prod, test, shared."
  }
}

variable "project_id" {
  description = "Project that hosts the workload identity pool and the service accounts."
  type        = string
}

variable "create" {
  description = "Whether to create any resources. Set false to plan nothing."
  type        = bool
  default     = true
}

variable "github_org" {
  description = "GitHub organisation allowed to authenticate. Tokens from any other owner are rejected by the provider attribute condition."
  type        = string
  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.github_org))
    error_message = "github_org must match ^[A-Za-z0-9-]+$."
  }
}

variable "repositories" {
  description = "Map of repository name (without the organisation) to the service account it may impersonate and the environments and branches allowed. Each environment and branch becomes one exact subject binding."
  type = map(object({
    service_account_email = string
    environments          = optional(list(string), [])
    branches              = optional(list(string), ["main"])
  }))
  default = {}
  validation {
    condition     = alltrue([for k in keys(var.repositories) : can(regex("^[A-Za-z0-9_.-]+$", k))])
    error_message = "repositories keys must be repository names matching ^[A-Za-z0-9_.-]+$ (no organisation prefix)."
  }
  validation {
    condition     = alltrue([for r in values(var.repositories) : length(r.environments) + length(r.branches) > 0])
    error_message = "Every repository must declare at least one environment or branch."
  }
  validation {
    condition = alltrue([
      for r in values(var.repositories) :
      alltrue([for v in concat(r.environments, r.branches) : length(v) > 0 && !can(regex("[*?:]", v))])
    ])
    error_message = "Environment and branch names must be non-empty and contain no wildcard or colon characters."
  }
}

variable "pool_display_name" {
  description = "Display name of the workload identity pool. Null (default) uses name. Set it to adopt an existing pool whose display name differs from its id."
  type        = string
  default     = null
  validation {
    condition     = var.pool_display_name == null ? true : length(var.pool_display_name) <= 32
    error_message = "pool_display_name must be at most 32 characters."
  }
}

variable "provider_id" {
  description = "Id of the OIDC provider inside the pool. Default github. Set it to adopt an existing provider created under another id; changing it on a managed provider forces a new one."
  type        = string
  default     = "github"
  validation {
    condition     = can(regex("^[a-z0-9-]{4,32}$", var.provider_id)) && !startswith(var.provider_id, "gcp-")
    error_message = "provider_id must match ^[a-z0-9-]{4,32}$ and must not start with gcp-."
  }
}

variable "provider_display_name" {
  description = "Display name of the OIDC provider. Default github."
  type        = string
  default     = "github"
  validation {
    condition     = length(var.provider_display_name) <= 32
    error_message = "provider_display_name must be at most 32 characters."
  }
}

variable "attribute_condition" {
  description = "CEL attribute condition of the OIDC provider. Null (default) uses assertion.repository_owner == \"<github_org>\". An override takes the place of that check entirely, so keeping tokens restricted to the organisation becomes the caller's responsibility."
  type        = string
  default     = null
  validation {
    condition     = var.attribute_condition == null ? true : length(trimspace(var.attribute_condition)) > 0
    error_message = "attribute_condition must be null or a non-empty expression."
  }
}

variable "extra_attribute_mapping" {
  description = "Attribute mappings merged over the module's default map; a key that exists in the default map overrides it. attribute.repository_ref and attribute.repository_environment drive the service account bindings and cannot be changed (a precondition on the provider rejects the plan). Keys must start with google. or attribute. (for example attribute.workflow)."
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for k in keys(var.extra_attribute_mapping) : can(regex("^(google|attribute)\\.[A-Za-z0-9_]+$", k))])
    error_message = "extra_attribute_mapping keys must match ^(google|attribute)\\.[A-Za-z0-9_]+$."
  }
}

variable "labels" {
  description = "Labels merged onto every labelable resource, applied last. Workload identity pools and providers accept no labels, so these are only exposed through the labels output for callers to reuse."
  type        = map(string)
  default     = {}
}
