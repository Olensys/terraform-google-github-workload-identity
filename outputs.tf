output "id" {
  description = "Resource ID of the workload identity pool. Null when create is false."
  value       = try(google_iam_workload_identity_pool.this[0].id, null)
}

output "name" {
  description = "Workload identity pool id (the name input). Null when create is false."
  value       = var.create ? var.name : null
}

output "self_link" {
  description = "Full resource name of the pool (projects/<number>/locations/global/workloadIdentityPools/<name>). Null when create is false."
  value       = try(google_iam_workload_identity_pool.this[0].name, null)
}

output "provider_name" {
  description = "Full resource name of the GitHub provider; pass as workload_identity_provider to google-github-actions/auth. Null when create is false."
  value       = try(google_iam_workload_identity_pool_provider.github[0].name, null)
}

output "pool_name" {
  description = "Full resource name of the workload identity pool. Null when create is false."
  value       = try(google_iam_workload_identity_pool.this[0].name, null)
}

output "subjects" {
  description = "Map of repository name to the exact GitHub subjects bound to its service account. Null when create is false."
  value       = var.create ? local.subjects : null
}

output "labels" {
  description = "Labels with context.extra_tags merged in. Pools and providers accept no labels, so none are applied to resources. Null when create is false."
  value       = var.create ? local.labels : null
}
