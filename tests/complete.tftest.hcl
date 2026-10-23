# Run only by the nightly integration workflow, against real cloud credentials.
# Set TF_VAR_project_id and TF_VAR_service_account_email in the workflow environment.
run "apply_minimal" {
  command = apply

  module {
    source = "./examples/minimal"
  }
}
