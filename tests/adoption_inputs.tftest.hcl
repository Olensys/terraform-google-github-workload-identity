# Pass-through inputs that let a caller import an existing pool and provider
# without a live change. Every default reproduces the previous hard-coded value.
mock_provider "google" {}

variables {
  context = {
    organization = "olensys"
    environment  = "test"
    application  = "example"
    owner        = "platform"
    cost_center  = "eng"
  }
  name       = "example"
  project_id = "demo-project"
  github_org = "acme"
  repositories = {
    api = {
      service_account_email = "api-deployer@demo-project.iam.gserviceaccount.com"
    }
  }
}

run "test_defaults_match_previous_literals" {
  command = plan

  assert {
    condition     = google_iam_workload_identity_pool.this[0].display_name == "example"
    error_message = "pool display name must default to name."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].workload_identity_pool_provider_id == "github"
    error_message = "provider id must default to github."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].display_name == "github"
    error_message = "provider display name must default to github."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].attribute_condition == "assertion.repository_owner == \"acme\""
    error_message = "attribute condition must default to the repository owner check."
  }

  assert {
    condition     = length(google_iam_workload_identity_pool_provider.github[0].attribute_mapping) == 8
    error_message = "the default attribute mapping must keep its eight entries."
  }
}

run "test_pool_display_name_override" {
  command = plan

  variables {
    pool_display_name = "GitHub Actions"
  }

  assert {
    condition     = google_iam_workload_identity_pool.this[0].display_name == "GitHub Actions"
    error_message = "pool_display_name must be passed through."
  }
}

run "test_provider_id_and_display_name_override" {
  command = plan

  variables {
    provider_id           = "github-actions"
    provider_display_name = "GitHub Actions OIDC"
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].workload_identity_pool_provider_id == "github-actions"
    error_message = "provider_id must be passed through."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].display_name == "GitHub Actions OIDC"
    error_message = "provider_display_name must be passed through."
  }
}

run "test_provider_id_validation" {
  command = plan

  variables {
    provider_id = "gcp-github"
  }

  expect_failures = [var.provider_id]
}

run "test_attribute_condition_override" {
  command = plan

  variables {
    attribute_condition = "assertion.repository_owner == \"acme\" && assertion.ref == \"refs/heads/main\""
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].attribute_condition == "assertion.repository_owner == \"acme\" && assertion.ref == \"refs/heads/main\""
    error_message = "attribute_condition must replace the default expression."
  }
}

run "test_attribute_condition_rejects_blank" {
  command = plan

  variables {
    attribute_condition = "  "
  }

  expect_failures = [var.attribute_condition]
}

run "test_extra_attribute_mapping_adds_and_overrides" {
  command = plan

  variables {
    extra_attribute_mapping = {
      "attribute.workflow" = "assertion.workflow"
      "attribute.actor"    = "assertion.actor_id"
    }
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].attribute_mapping["attribute.workflow"] == "assertion.workflow"
    error_message = "a new key must be added to the mapping."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].attribute_mapping["attribute.actor"] == "assertion.actor_id"
    error_message = "an existing key must be overridden by the caller's value."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].attribute_mapping["attribute.repository_ref"] == "assertion.repository + \":\" + assertion.ref"
    error_message = "the binding pairs must remain in the merged mapping."
  }

  assert {
    condition     = length(google_iam_workload_identity_pool_provider.github[0].attribute_mapping) == 9
    error_message = "merged mapping must hold the eight defaults plus one new key."
  }
}

run "test_extra_attribute_mapping_cannot_change_binding_pairs" {
  command = plan

  variables {
    extra_attribute_mapping = {
      "attribute.repository_ref" = "assertion.sub"
    }
  }

  expect_failures = [google_iam_workload_identity_pool_provider.github[0]]
}

run "test_extra_attribute_mapping_key_validation" {
  command = plan

  variables {
    extra_attribute_mapping = {
      "workflow" = "assertion.workflow"
    }
  }

  expect_failures = [var.extra_attribute_mapping]
}
