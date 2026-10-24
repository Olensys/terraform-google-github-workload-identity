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
    web = {
      service_account_email = "web-deployer@demo-project.iam.gserviceaccount.com"
      environments          = ["prod", "staging"]
      branches              = ["main", "release"]
    }
  }
}

run "test_provider_restricted_to_org" {
  command = plan

  assert {
    condition     = strcontains(google_iam_workload_identity_pool_provider.github[0].attribute_condition, "\"acme\"")
    error_message = "attribute_condition must restrict repository_owner to the GitHub org."
  }
}

run "test_member_per_repository" {
  command = plan

  assert {
    condition     = length(google_service_account_iam_member.wif) == 5
    error_message = "Expected one member per subject (api: 1, web: 4)."
  }
}

run "test_attribute_mapping_has_ref_and_environment_pairs" {
  command = plan

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].attribute_mapping["attribute.repository_ref"] == "assertion.repository + \":\" + assertion.ref"
    error_message = "attribute.repository_ref must combine repository and ref."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].attribute_mapping["attribute.repository_environment"] == "assertion.repository + \":\" + assertion.environment"
    error_message = "attribute.repository_environment must combine repository and environment."
  }

  assert {
    condition     = google_iam_workload_identity_pool_provider.github[0].attribute_mapping["google.subject"] == "assertion.sub"
    error_message = "google.subject must stay assertion.sub."
  }
}

run "test_branch_member_format" {
  command = apply

  assert {
    condition     = contains(output.subjects["api"], "principalSet://iam.googleapis.com/${output.pool_name}/attribute.repository_ref/acme/api:refs/heads/main")
    error_message = "Branch member must be a principalSet on attribute.repository_ref."
  }
}

run "test_environment_member_format" {
  command = apply

  assert {
    condition     = contains(output.subjects["web"], "principalSet://iam.googleapis.com/${output.pool_name}/attribute.repository_environment/acme/web:prod")
    error_message = "Environment member must be a principalSet on attribute.repository_environment."
  }

  assert {
    condition     = alltrue([for m in values(google_service_account_iam_member.wif)[*].member : startswith(m, "principalSet://")])
    error_message = "No principal:// subject member may remain."
  }
}

run "test_create_false_plans_nothing" {
  command = plan

  variables {
    create = false
  }

  assert {
    condition     = output.id == null && output.name == null && output.self_link == null && output.provider_name == null && output.pool_name == null && output.subjects == null && output.labels == null
    error_message = "All outputs must be null when create is false."
  }
}

run "test_repository_needs_a_subject" {
  command = plan

  variables {
    repositories = {
      api = {
        service_account_email = "api-deployer@demo-project.iam.gserviceaccount.com"
        branches              = []
      }
    }
  }

  expect_failures = [var.repositories]
}

run "test_name_length_validation" {
  command = plan

  variables {
    name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  expect_failures = [var.name]
}

run "test_tags_contract" {
  command = plan

  variables {
    labels = { owner = "x" }
    context = {
      organization = "olensys"
      environment  = "test"
      application  = "example"
      owner        = "platform"
      cost_center  = "eng"
      extra_tags   = { Owner = "y", Team = "Core Team" }
    }
  }

  assert {
    condition     = output.labels.owner == "x"
    error_message = "var.labels must win over context.extra_tags."
  }

  assert {
    condition     = output.labels.team == "core-team"
    error_message = "context.extra_tags must be merged and normalised."
  }
}
