# Changelog

## [1.1.1](https://github.com/Olensys/terraform-google-github-workload-identity/compare/v1.1.0...v1.1.1) (2026-10-24)


### Bug Fixes

* run integration on change and weekly instead of nightly ([8b2443c](https://github.com/Olensys/terraform-google-github-workload-identity/commit/8b2443c1f288044c1fc6b8472c626931969cf4ca))

## 1.1.0

### Fixes

- normalise `context.extra_tags` keys and values to valid GCP label syntax (lowercase, `[^a-z0-9_-]` replaced by `-`, 63 characters); `labels` are applied verbatim and win

### Tests

- `test_tags_contract` now covers mixed-case extra tags and verifies normalisation

### Docs

- Usage shows the naming module; Opinions describe label normalisation

### Behaviour changes

- `labels` output and applied labels now contain normalised keys and values for `context.extra_tags` (for example `Team = "Core Team"` becomes `team = "core-team"`). Callers that relied on mixed-case or space-containing extra tags must expect the normalised form; values passed in `labels` are unchanged.

## 1.0.0

- Workload Identity Federation pool and GitHub OIDC provider restricted to one GitHub organisation.
- Per-repository service account bindings using exact environment and branch subjects; no repository-wide principalSet.
