locals {
  extra_labels = { for k, v in var.context.extra_tags :
  substr(replace(lower(k), "/[^a-z0-9_-]/", "-"), 0, 63) => substr(replace(lower(v), "/[^a-z0-9_-]/", "-"), 0, 63) }
  labels = merge(local.extra_labels, var.labels)

  # One exact attribute value per environment and per branch, bound as a
  # principalSet on a repository+ref / repository+environment pair. GitHub's
  # immutable subject (repo:ORG@ID/REPO@ID:...) is never matched directly, and
  # no repository-wide or organisation-wide principalSet is ever granted.
  subjects = {
    for repo, cfg in var.repositories : repo => concat(
      [for e in cfg.environments : "attribute.repository_environment/${var.github_org}/${repo}:${e}"],
      [for b in cfg.branches : "attribute.repository_ref/${var.github_org}/${repo}:refs/heads/${b}"],
    )
  }

  bindings = merge([
    for repo, subs in local.subjects : {
      for s in subs : "${repo}|${s}" => {
        service_account_email = var.repositories[repo].service_account_email
        subject               = s
      }
    }
  ]...)

  # Pairs used by the bindings; they do not depend on the format of the sub
  # claim. Callers may add or override other entries through
  # extra_attribute_mapping, but these two must stay as they are.
  binding_attribute_mapping = {
    "attribute.repository_ref"         = "assertion.repository + \":\" + assertion.ref"
    "attribute.repository_environment" = "assertion.repository + \":\" + assertion.environment"
  }

  default_attribute_mapping = merge({
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
    "attribute.environment"      = "assertion.environment"
  }, local.binding_attribute_mapping)

  attribute_mapping = merge(local.default_attribute_mapping, var.extra_attribute_mapping)

  attribute_condition = var.attribute_condition == null ? "assertion.repository_owner == \"${var.github_org}\"" : var.attribute_condition
}

resource "google_iam_workload_identity_pool" "this" {
  count = var.create ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = var.name
  display_name              = var.pool_display_name == null ? var.name : var.pool_display_name
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.create ? 1 : 0

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = var.provider_display_name

  attribute_mapping   = local.attribute_mapping
  attribute_condition = local.attribute_condition

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  lifecycle {
    precondition {
      condition = alltrue([
        for k, v in local.binding_attribute_mapping : lookup(local.attribute_mapping, k, null) == v
      ])
      error_message = "extra_attribute_mapping must not change attribute.repository_ref or attribute.repository_environment; the service account bindings depend on them."
    }
  }
}

resource "google_service_account_iam_member" "wif" {
  for_each = var.create ? local.bindings : {}

  service_account_id = "projects/${var.project_id}/serviceAccounts/${each.value.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.this[0].name}/${each.value.subject}"
}
