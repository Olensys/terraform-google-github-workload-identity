# Run only by the nightly integration workflow, against real cloud credentials.
# Set TF_VAR_project_id and TF_VAR_service_account_email in the workflow environment.
run "apply_minimal" {
  command = apply

  # Deleted workload identity pools stay reserved for 30 days, so every run needs a fresh name.
  variables {
    name = "olensys-it-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  }

  module {
    source = "./examples/minimal"
  }
}
