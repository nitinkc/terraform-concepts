# Concept index

The lookup table for everything else. Each row is one concept and every place it appears:
the theory that defines it, the Stage 2 topic that isolates it, the GCP lab that runs it
for real, the code that depends on it, and the quiz that checks whether you actually have
it.

Read a row left to right when learning something new. Read it right to left when something
breaks and you need to find where the concept was explained. `§N` refers to the
[theory pages](index.md), numbered 1–19.

## Core mechanics

| Concept | Theory | Stage 2 | Stage 3 | Code | Quiz |
|---|---|---|---|---|---|
| Providers, `required_providers` | [§2](02-providers-and-authentication.md) | [Provider versions](../basics/11-provider-versions.md) | [Lab 1](../gcp/02-lab-notes.md#lab-1-local-state) | `01-basics/7-version-constraints/`, `*/infra/versions.tf` | [Providers](../quiz/01-providers-and-auth.md) |
| Provider auth (ADC, `google_client_config`) | [§2](02-providers-and-authentication.md), [§11](11-data-sources.md) | — | [Prereqs](../gcp/index.md#prerequisites) | `backend/infra/providers.tf` | [Providers](../quiz/01-providers-and-auth.md) |
| Provider block defaults vs resource-level args | [§2](02-providers-and-authentication.md) | [Provider versions](../basics/11-provider-versions.md#a-provider-block-isnt-always-needed) | [Core root](../gcp/01-core-root.md) | `02-gcp-terraform/01-core-gcp-resources/main.tf` | [Providers](../quiz/01-providers-and-auth.md) |
| Provider aliasing (multi-region/project) | [§2](02-providers-and-authentication.md) | — | [Lab 14](../gcp/02-lab-notes.md#lab-14-provider-aliasing-multi-region-multi-project) | — | — |
| `terraform init` | [§3](03-init-and-version-constraints.md) | [Provider versions](../basics/11-provider-versions.md) | — | — | [Providers](../quiz/01-providers-and-auth.md) |
| Version constraints & the lock file | [§3](03-init-and-version-constraints.md) | [Provider versions](../basics/11-provider-versions.md#the-operators) | — | `01-basics/7-version-constraints/` | — |
| Resource identity & force-replacement | [§5](05-resource-identity-and-change.md) | [Resources and state](../basics/01-resources-and-state.md) | — | — | [GKE](../quiz/05-gke-and-workload-identity.md) |
| Resources vs data sources | [§11](11-data-sources.md) | [Data sources](../basics/06-data-sources.md) | [Lab 7](../gcp/02-lab-notes.md#lab-7-data-sources) | `01-basics/6-data-sources/`, `02-gcp-terraform/01-core-gcp-resources/data.tf` | [Resources](../quiz/02-resources-state-and-drift.md) |
| Implicit vs explicit dependencies | [§6](06-dependencies-and-the-graph.md) | [References and dependencies](../basics/04-references-and-dependencies.md) | [Lab 3](../gcp/02-lab-notes.md#lab-3-implicit-dependency-iam-binding) | `01-basics/4-dependencies/`, `backend/infra/main.tf` | — |
| The dependency graph (`terraform graph`) | [§6](06-dependencies-and-the-graph.md) | [References and dependencies](../basics/04-references-and-dependencies.md#seeing-the-graph) | [Core root](../gcp/01-core-root.md#run) | `01-basics/4-dependencies/implicit/graph.svg` | — |

## State

| Concept | Theory | Stage 2 | Stage 3 | Code | Quiz |
|---|---|---|---|---|---|
| State file & the apply model | [§4](04-resources-and-state.md) | [Resources and state](../basics/01-resources-and-state.md) | [Lab 1](../gcp/02-lab-notes.md#lab-1-local-state) | `01-basics/1-create-local-file/` | [Resources](../quiz/02-resources-state-and-drift.md) |
| Remote backends (GCS) | [§14](14-backends-and-state-security.md) | — | [Lab 2](../gcp/02-lab-notes.md#lab-2-remote-state-gcs-backend) | `02-gcp-terraform/01-core-gcp-resources/backend.tf` | — |
| Drift, refresh, import | [§13](13-state-lifecycle.md) | [State surgery](../basics/12-state-surgery.md) | [Lab 11](../gcp/02-lab-notes.md#lab-11-import-drift-detection) | — | [Resources](../quiz/02-resources-state-and-drift.md) |
| State surgery (`mv`/`rm`/`import`) | [§13](13-state-lifecycle.md) | [State surgery](../basics/12-state-surgery.md) | [Lab 6](../gcp/02-lab-notes.md#lab-6-state-surgery-mv-rm-import) | — | [Resources](../quiz/02-resources-state-and-drift.md) |
| State file security & sensitive values | [§14](14-backends-and-state-security.md) | [Validation and sensitive values](../basics/10-validation-and-sensitive-values.md#sensitive-masking-not-encryption) | — | `infrastructure/infra/secrets.tf` | — |
| Workspaces | [§13](13-state-lifecycle.md) | — | [Lab 10](../gcp/02-lab-notes.md#lab-10-workspaces-multi-environment-state-isolation) | `backend/infra/terraform.tfstate.d/` | [Variables](../quiz/03-variables-expressions-and-guards.md) |

## Expressions & structure

| Concept | Theory | Stage 2 | Stage 3 | Code | Quiz |
|---|---|---|---|---|---|
| Variables & precedence | [§7](07-variables-and-locals.md#variable-precedence) | [Variables](../basics/02-variables.md#precedence-the-gotcha-that-costs-real-time) | [Lab 15](../gcp/02-lab-notes.md#lab-15-terraformtfvars-variable-precedence) | `01-basics/2-variable-use/`, `02-gcp-terraform/01-core-gcp-resources/terraform.tfvars` | [Variables](../quiz/03-variables-expressions-and-guards.md) |
| Variable validation | [§7](07-variables-and-locals.md) | [Validation](../basics/10-validation-and-sensitive-values.md#validation-reject-bad-input-early) | — | — | — |
| `locals` | [§7](07-variables-and-locals.md) | [Locals](../basics/03-locals.md) | [Lab 8](../gcp/02-lab-notes.md#lab-8-locals-computedderived-values) | `02-gcp-terraform/01-core-gcp-resources/locals.tf` | — |
| `for` expressions, `try`, `one`, splat | [§8](08-expressions-and-conditionals.md) | — | [Lab 13](../gcp/02-lab-notes.md#lab-13-for_each-over-modules) | `sample-program/infra/main.tf` | [Variables](../quiz/03-variables-expressions-and-guards.md) |
| Outputs | [§10](10-outputs.md) | [Outputs](../basics/05-outputs.md) | [Lab 7](../gcp/02-lab-notes.md#lab-7-data-sources) | `02-gcp-terraform/01-core-gcp-resources/outputs.tf`, `*/infra/outputs.tf` | — |
| Attribute references | [§6](06-dependencies-and-the-graph.md) | [References and dependencies](../basics/04-references-and-dependencies.md#attribute-references) | — | `01-basics/3-resource-attribute-reference/` | — |
| `count` | [§9](09-count-for-each-and-dynamic.md#count-positional) | [count and for_each](../basics/07-count-and-for-each.md#count-positional) | [Lab 4](../gcp/02-lab-notes.md#lab-4-count-indexed-multiple-resources) | `02-gcp-terraform/01-core-gcp-resources/resources.tf` (commented) | [Variables](../quiz/03-variables-expressions-and-guards.md) |
| Conditionals / `count = 0` | [§8](08-expressions-and-conditionals.md) | [Conditionals](../basics/08-conditionals.md) | — | `backend/infra/cloudsql.tf` | [Variables](../quiz/03-variables-expressions-and-guards.md) |
| `for_each` | [§9](09-count-for-each-and-dynamic.md#for_each-keyed) | [count and for_each](../basics/07-count-and-for-each.md#for_each-keyed) | [Lab 5](../gcp/02-lab-notes.md#lab-5-for_each-keyed-multiple-resources) | `02-gcp-terraform/01-core-gcp-resources/resources.tf`, `backend/infra/iam.tf` | [Variables](../quiz/03-variables-expressions-and-guards.md) |
| `for_each` over modules | [§9](09-count-for-each-and-dynamic.md#for_each-over-modules), [§12](12-modules.md) | — | [Lab 13](../gcp/02-lab-notes.md#lab-13-for_each-over-modules) | `sample-program/infra/main.tf` | [Variables](../quiz/03-variables-expressions-and-guards.md) |
| **Guard propagation** | [§8](08-expressions-and-conditionals.md#guard-propagation) | [Conditionals](../basics/08-conditionals.md#guard-propagation) | [Lab 13](../gcp/02-lab-notes.md#lab-13-for_each-over-modules) | `sample-program/infra/main.tf` | [Variables](../quiz/03-variables-expressions-and-guards.md) |
| `dynamic` blocks | [§9](09-count-for-each-and-dynamic.md#dynamic-repeating-a-nested-block) | — | [Lab 12](../gcp/02-lab-notes.md#lab-12-dynamic-blocks) | `02-gcp-terraform/01-core-gcp-resources/resources.tf`, `backend/infra/rbac.tf` | — |
| Modules | [§12](12-modules.md) | — | [Lab 9](../gcp/02-lab-notes.md#lab-9-modules-packaging-reusable-infra) | `02-gcp-terraform/01-core-gcp-resources/modules/gcp-vm/`, `sample-program/infra/modules/` | — |
| `lifecycle` meta-arguments | [§5](05-resource-identity-and-change.md#lifecycle-overriding-the-default-behaviour) | [Lifecycle](../basics/09-lifecycle.md) | [Lab 16](../gcp/02-lab-notes.md#lab-16-lifecycle-meta-arguments) | `01-basics/5-lifecycle/`, `cloudsql/infra/cloudsql.tf` | — |
| Provisioners / `null_resource` | [§16](16-gitops-and-cicd.md) | [Provisioners](../basics/13-provisioners-and-archive.md#null_resource-and-local-exec) | [Lab 17](../gcp/02-lab-notes.md#lab-17-provisioners-null_resource-brief) | — | — |
| `archive_file` | — | [archive_file](../basics/13-provisioners-and-archive.md#archive_file) | — | — | — |
| File naming conventions | [§17](17-project-structure.md) | [Conventions](../basics/index.md#conventions) | [Core root](../gcp/01-core-root.md#whats-in-here) | `02-gcp-terraform/01-core-gcp-resources/` | — |
| Root boundaries & blast radius | [§17](17-project-structure.md#a-root-is-a-blast-radius) | — | — | `acme-.../` (5 roots) | — |

## Multi-repo & platform

| Concept | Theory | Stage 2 | Stage 3 | Code | Quiz |
|---|---|---|---|---|---|
| Cross-repo sharing: Consul KV vs `terraform_remote_state` | [§15](15-cross-config-composition.md) | — | [Lab 18](../gcp/02-lab-notes.md#lab-18-capstone-apply-to-real-acme-sampleapp-repo) | `sample-program/infra/main.tf`, `infrastructure/infra/outputs.tf` | [Multi-repo](../quiz/04-multirepo-and-consul.md) |
| Publish/consume ordering & failure modes | [§15](15-cross-config-composition.md#failure-modes-in-the-order-youll-hit-them) | — | — | `backend/infra/main.tf` | [Multi-repo](../quiz/04-multirepo-and-consul.md) |
| Resource ownership across repo boundaries | [§15](15-cross-config-composition.md) | — | — | `infrastructure/infra/iam.tf` | [Multi-repo](../quiz/04-multirepo-and-consul.md) |
| GKE clusters & node pools | — | — | — | `sample-program/infra/modules/gke/main.tf` | [GKE](../quiz/05-gke-and-workload-identity.md) |
| Node service accounts | — | — | — | `sample-program/infra/modules/gke/main.tf` | [GKE](../quiz/05-gke-and-workload-identity.md) |
| Workload Identity (GSA ↔ KSA annotation) | — | — | — | `backend/infra/main.tf`, `frontend/infra/main.tf` | [GKE](../quiz/05-gke-and-workload-identity.md) |
| Node capacity vs allocatable | — | — | — | `sample-program/infra/terraform.tfvars` | [GKE](../quiz/05-gke-and-workload-identity.md) |
| Kubernetes RBAC from Terraform | — | — | — | `backend/infra/rbac.tf` | [GKE](../quiz/05-gke-and-workload-identity.md) |
| `helm_release` | — | — | — | `backend/infra/main.tf`, `frontend/infra/vip.tf` | — |
| GitOps / CI-CD execution model | [§16](16-gitops-and-cicd.md) | — | — | `.github/workflows/publish-docs.yml` | — |
| Independent verification (not trusting `apply`) | [§15](15-cross-config-composition.md#failure-modes-in-the-order-youll-hit-them) | — | — | `acme-.../verify-session.sh` | [Debugging](../quiz/06-debugging-and-verification.md) |
| Hypothesis-ordered debugging | — | — | — | [Session 3](../sessions/session-03.md) | [Debugging](../quiz/06-debugging-and-verification.md) |

## Gaps

Honest list of what has a theory entry or a lab but no counterpart elsewhere, so it's clear
what's genuinely covered versus what only looks covered:

- **Six Stage 2 topics have no folder under `01-basics/`** — locals, `count`/`for_each`,
  conditionals, validation and sensitive values, state surgery, and provisioners. The code
  on each page is runnable; it just has no committed home. See the
  [not-yet-implemented list](../basics/index.md#not-yet-implemented).
- **No GCP lab for variable validation or sensitive variables** — both are Stage 2 only.
- **The GKE/Workload Identity/Helm rows have no theory page.** That's deliberate — they're
  platform knowledge rather than Terraform mechanics — but it does mean the only
  explanation of them lives in the quiz and the [session notes](../sessions/index.md).
- **`helm_release`, Kubernetes RBAC and Cloud SQL** exist only in the sandbox, with no
  isolated lab to learn them in. They were learned in-place during sessions 2 and 3.
- **`archive_file` has no theory entry and no GCP lab** — it's a single Stage 2 page.

Closed since the last revision: `count`, `for_each`, `dynamic`, modules, workspaces,
`lifecycle` meta-arguments and provider aliasing all now have theory sections
([§9](09-count-for-each-and-dynamic.md), [§12](12-modules.md),
[§13](13-state-lifecycle.md), [§5](05-resource-identity-and-change.md),
[§2](02-providers-and-authentication.md)).

## Maintaining this page

Add a row when a session introduces a concept that isn't already listed. A row with only a
`Code` cell filled in is a signal, not a defect — it means you've used something in the
sandbox that you've never isolated in a lab or tested in the quiz, which is exactly the
thing that later turns into a debugging session.
