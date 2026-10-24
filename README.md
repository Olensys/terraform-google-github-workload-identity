# terraform-google-github-workload-identity

Workload Identity Federation pool and GitHub OIDC provider, restricted to one GitHub organisation, with per-repository service account bindings

## Opinions

- One GitHub organisation per pool: the provider's attribute condition is `assertion.repository_owner == "<github_org>"`, so tokens from any other owner are rejected before any binding is evaluated.
- Exact-subject bindings only. Each environment is bound as a `principalSet` on `attribute.repository_environment/<org>/<repo>:<env>` and each branch on `attribute.repository_ref/<org>/<repo>:refs/heads/<branch>`. No `principalSet` over a whole repository or organisation is ever granted; wildcard characters in environment and branch names are rejected.
- Every repository must declare at least one environment or branch (branches default to `["main"]`).
- One pool per project: `name` is the pool id (4 to 32 characters) and the provider id is always `github`. An empty `repositories` map is valid; the pool and provider are created without bindings.
- Pools and providers accept no labels; `labels` and `context.extra_tags` are merged and exposed through the `labels` output only.
- The service account's `roles/iam.workloadIdentityUser` binding is the only IAM this module grants; the service accounts themselves, and their permissions, are managed elsewhere.
- `context.extra_tags` keys and values are normalised to valid GCP label syntax (lowercase, `[^a-z0-9_-]` → `-`, 63 chars); `labels` are applied verbatim and win.

## Immutable OIDC subjects

GitHub can issue tokens whose `sub` claim is `repo:ORG@ORG_ID/REPO@REPO_ID:ref:refs/heads/BRANCH` (immutable subject), instead of `repo:ORG/REPO:...`. Bindings on the `sub` string (`principal://.../subject/...`) therefore never match. This module binds on claims that do not change with the subject format: the provider maps `attribute.repository_ref` (`assertion.repository + ":" + assertion.ref`) and `attribute.repository_environment` (`assertion.repository + ":" + assertion.environment`), and each service account gets a `principalSet` on those attributes, for example `principalSet://iam.googleapis.com/<pool>/attribute.repository_ref/my-org/app:refs/heads/main`. `google.subject` stays `assertion.sub`. The provider's attribute condition still requires `assertion.repository_owner == "<github_org>"`, so tokens from other owners are rejected first. The `subjects` output lists these member strings.

## Usage

```hcl
module "naming" {
  source  = "git::https://github.com/Olensys/terraform-null-naming.git?ref=v1.0.1"
  context = var.context
}

module "this" {
  source = "git::https://github.com/Olensys/terraform-google-github-workload-identity.git?ref=v1.1.0"

  name       = module.naming.name
  project_id = "my-project"
  github_org = "my-org"
  context = var.context

  repositories = {
    app = {
      service_account_email = "deployer@my-project.iam.gserviceaccount.com"
      environments          = ["prod"]
      branches              = ["main"]
    }
  }
  labels  = module.naming.labels
}
```

Authenticate from a workflow (requires `permissions: id-token: write`):

```yaml
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/example-github/providers/github
    service_account: deployer@my-project.iam.gserviceaccount.com
```

Set `workload_identity_provider` to the `provider_name` output and `service_account` to the email passed in `repositories[*].service_account_email`.

## Integration testing

Deleted workload identity pools stay reserved for 30 days, so the integration test uses a unique pool name per run.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.0, < 8.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.0, < 8.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [google_iam_workload_identity_pool.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool) | resource |
| [google_iam_workload_identity_pool_provider.github](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider) | resource |
| [google_service_account_iam_member.wif](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_member) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_context"></a> [context](#input\_context) | Deployment context used for naming, tagging and environment-dependent defaults. | <pre>object({<br/>    organization = string<br/>    environment  = string<br/>    application  = string<br/>    component    = optional(string)<br/>    owner        = string<br/>    cost_center  = string<br/>    extra_tags   = optional(map(string), {})<br/>  })</pre> | n/a | yes |
| <a name="input_github_org"></a> [github\_org](#input\_github\_org) | GitHub organisation allowed to authenticate. Tokens from any other owner are rejected by the provider attribute condition. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Workload identity pool id. Lowercase letters, digits and hyphens, 4 to 32 characters (the provider limit). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project that hosts the workload identity pool and the service accounts. | `string` | n/a | yes |
| <a name="input_create"></a> [create](#input\_create) | Whether to create any resources. Set false to plan nothing. | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels merged onto every labelable resource, applied last. Workload identity pools and providers accept no labels, so these are only exposed through the labels output for callers to reuse. | `map(string)` | `{}` | no |
| <a name="input_repositories"></a> [repositories](#input\_repositories) | Map of repository name (without the organisation) to the service account it may impersonate and the environments and branches allowed. Each environment and branch becomes one exact subject binding. | <pre>map(object({<br/>    service_account_email = string<br/>    environments          = optional(list(string), [])<br/>    branches              = optional(list(string), ["main"])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | Resource ID of the workload identity pool. Null when create is false. |
| <a name="output_labels"></a> [labels](#output\_labels) | Labels with context.extra\_tags merged in. Pools and providers accept no labels, so none are applied to resources. Null when create is false. |
| <a name="output_name"></a> [name](#output\_name) | Workload identity pool id (the name input). Null when create is false. |
| <a name="output_pool_name"></a> [pool\_name](#output\_pool\_name) | Full resource name of the workload identity pool. Null when create is false. |
| <a name="output_provider_name"></a> [provider\_name](#output\_provider\_name) | Full resource name of the GitHub provider; pass as workload\_identity\_provider to google-github-actions/auth. Null when create is false. |
| <a name="output_self_link"></a> [self\_link](#output\_self\_link) | Full resource name of the pool (projects/<number>/locations/global/workloadIdentityPools/<name>). Null when create is false. |
| <a name="output_subjects"></a> [subjects](#output\_subjects) | Map of repository name to the principalSet members bound to its service account (on attribute.repository\_ref and attribute.repository\_environment). Null when create is false. |
<!-- END_TF_DOCS -->
