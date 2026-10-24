terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = { source = "hashicorp/google", version = ">= 6.0, < 8.0" }
  }
}

variable "project_id" {
  description = "Project that hosts the pool."
  type        = string
}

variable "service_account_email" {
  description = "Email of the service account the repository may impersonate."
  type        = string
}

variable "name" {
  description = "Workload identity pool id. Deleted pools stay reserved for 30 days, so repeated test runs pass a unique value."
  type        = string
  default     = "olensys-test-wlif"
}

module "this" {
  source = "../../"

  name       = var.name
  project_id = var.project_id
  github_org = "example-org"
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "wlif"
    owner        = "platform"
    cost_center  = "eng"
  }

  repositories = {
    app = { service_account_email = var.service_account_email }
  }
}
