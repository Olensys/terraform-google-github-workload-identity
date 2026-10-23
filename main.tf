locals {
  labels = merge(var.context.extra_tags, var.labels)

  # One exact subject per environment and per branch. No repository-wide
  # principalSet is ever granted.
  subjects = {
    for repo, cfg in var.repositories : repo => concat(
      [for e in cfg.environments : "repo:${var.github_org}/${repo}:environment:${e}"],
      [for b in cfg.branches : "repo:${var.github_org}/${repo}:ref:refs/heads/${b}"],
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
}

resource "google_iam_workload_identity_pool" "this" {
  count = var.create ? 1 : 0

  project                   = var.project_id
  workload_identity_pool_id = var.name
  display_name              = var.name
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.create ? 1 : 0

  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.this[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "github"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
    "attribute.environment"      = "assertion.environment"
  }

  attribute_condition = "assertion.repository_owner == \"${var.github_org}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "wif" {
  for_each = var.create ? local.bindings : {}

  service_account_id = "projects/${var.project_id}/serviceAccounts/${each.value.service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.this[0].name}/subject/${each.value.subject}"
}
