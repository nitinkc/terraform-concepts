# Terraform Architect's Reference

A unified, zero-noise reference combining **core theory**, **local-provider mechanics (`01-basics/`)**, **real GCP implementations (`02-gcp-terraform/`)**, and **multi-repo production architecture (`acme-sampleapp-.../`)**.

Each article is structured for rapid review and senior/architect-level interviews:

1. **Points to Keep in Mind** — architectural invariants, failure modes, and high-signal interview nuances.
2. **Local Cheatsheet (`01-basics/`)** — minimal, zero-cost HCL proving the mechanic on disk.
3. **GCP Implementation (`02-gcp-terraform/` & Sandbox)** — production-grade cloud patterns and real API gotchas.

---

## Sequential Reading Order

| # | Article | Core Focus & Interview Highlights | Local Code | GCP / Sandbox Code |
|---|---|---|---|---|
| 1 | [Execution Model, Providers & Auth](01-execution-model-and-providers.md) | 3-way diff, Core vs Provider, `required_providers` vs `provider {}`, ADC precedence, lock files, aliasing | `01-basics/7-version-constraints/` | `02-gcp-terraform/z-core-gcp-resources/main.tf` |
| 2 | [Resources, State Mechanics & Backends](02-resources-state-and-backends.md) | State ledger purpose, non-atomic apply, clobber vs 409, GCS backend chicken-and-egg, `plan` read-access security | `01-basics/1-create-local-file/` | `02-gcp-terraform/z-core-gcp-resources/backend.tf` |
| 3 | [Resource Identity, Change & Lifecycle](03-identity-lifecycle-and-change.md) | Address identity, `moved` blocks, in-place vs Force-New, `prevent_destroy`, `ignore_changes`, `create_before_destroy` | `01-basics/5-lifecycle/` | `cloudsql/infra/cloudsql.tf` |
| 4 | [Dependencies & the Execution Graph](04-dependencies-and-graph.md) | Implicit reference edges, when `depends_on` is required vs redundant, reverse destroy order, plan-time unknowns | `01-basics/3-…`, `01-basics/4-dependencies/` | `02-gcp-terraform/z-core-gcp-resources/network.tf` |
| 5 | [Variables, Precedence, Locals & Sensitive Data](05-variables-locals-and-security.md) | Exact variable precedence order, type constraints, `validation`, why `sensitive = true` is not encryption, volatile functions | `01-basics/2-variable-locals/` | `02-gcp-terraform/z-core-gcp-resources/locals.tf`, `variables.tf` |
| 6 | [Expressions, Conditionals & Guard Propagation](06-expressions-conditionals-and-guards.md) | Ternaries, `for` comprehensions, `try`/`one`/`coalesce`, `count = 0` empty-list trap, downstream **guard propagation** | `01-basics/cheatsheet/` | `backend/infra/cloudsql.tf`, `infrastructure/infra/` |
| 7 | [Repetition: `count`, `for_each` & `dynamic`](07-repetition-count-for-each-dynamic.md) | Index-shift destruction vs keyed stability, `for_each` over modules, `dynamic` nested blocks, plan-time key rule | `01-basics/cheatsheet/` | `02-gcp-terraform/z-core-gcp-resources/resources.tf` |
| 8 | [Data Sources, Outputs & Module Design](08-data-sources-outputs-and-modules.md) | Live `data` reads vs `resource`, `google_client_config` token expiry, `-raw` vs `-json`, module boundaries, `archive_file` vs `local-exec` | `01-basics/6-data-sources/` | `02-gcp-terraform/z-core-gcp-resources/data.tf`, `modules/` |
| 9 | [State Surgery, Drift, Import & Workspaces](09-state-surgery-drift-and-workspaces.md) | `state mv`/`rm`/`import`, import-vs-recreate decision framework, import diff trap, workspace isolation caveats | `01-basics/` | `02-gcp-terraform/3-acme-lab-step-by-step/` |
| 10 | [Production Architecture: Multi-Repo, GKE, Networking & CI/CD](10-architecture-multirepo-gke-and-cicd.md) | Root blast radius, Consul KV vs `terraform_remote_state`, VPC/IAP/Peering, GKE transient node pool & Workload Identity, GitOps PR attack surface | — | `02-gcp-terraform/1-2pc-…`, `2-2VPCs/`, `acme-sampleapp-…/` |
| 11 | [Master HCL, CLI & Glossary Cheatsheet](11-cli-and-hcl-cheatsheet.md) | Annotated all-in-one HCL reference, complete CLI lookup table, and 1-line architectural glossary | `01-basics/cheatsheet/main.tf` | All roots |

---

## Concept-to-Quiz Lookup (66 Questions Across 6 Topics)

| Concept | Reference Article | Quiz |
|---|---|---|
| Providers, `required_providers`, fallback defaults, ADC, `google_client_config`, `~>` constraints, `.terraform.lock.hcl`, provider aliasing, partial GCS backend, Org Policy 412 | [§1 Execution & Providers](01-execution-model-and-providers.md), [§2 State & Backends](02-resources-state-and-backends.md) | [Providers, Auth, Versions & Backends (10 Qs)](../quiz/01-providers-and-auth.md) |
| State ledger, non-atomic `apply`, `resource` vs `data`, clobber vs `409`, `import` vs recreate, `import` diff trap, `moved {}`, `prevent_destroy`, `ignore_changes`, `create_before_destroy`, `plan` state-read security | [§2 State & Backends](02-resources-state-and-backends.md), [§3 Identity & Lifecycle](03-identity-lifecycle-and-change.md), [§8 Data & Modules](08-data-sources-outputs-and-modules.md), [§9 State Surgery](09-state-surgery-drift-and-workspaces.md) | [Resources, Data, State, Lifecycle & Surgery (12 Qs)](../quiz/02-resources-state-and-drift.md) |
| 5-level variable precedence, `sensitive = true` plaintext state, volatile `timestamp()`, `validation {}`, `count` index shift vs `for_each`, plan-time unknown keys, `dynamic` blocks, `-raw` vs `-json`, `count = 0`, guard propagation | [§5 Variables & Locals](05-variables-locals-and-security.md), [§6 Guards](06-expressions-conditionals-and-guards.md), [§7 Repetition](07-repetition-count-for-each-dynamic.md), [§8 Data & Modules](08-data-sources-outputs-and-modules.md) | [Variables, Locals, Repetition, Outputs & Guards (13 Qs)](../quiz/03-variables-expressions-and-guards.md) |
| Implicit DAG vs `depends_on`, module state prefixing, `archive_file` vs `local-exec`, Consul KV vs `terraform_remote_state`, publish ordering, IAM grant ownership, workspaces vs directories, root blast radius, GitOps PR attack surface | [§4 Dependencies & Graph](04-dependencies-and-graph.md), [§8 Data & Modules](08-data-sources-outputs-and-modules.md), [§9 State Surgery](09-state-surgery-drift-and-workspaces.md), [§10 Production Architecture](10-architecture-multirepo-gke-and-cicd.md) | [Dependencies, Modules, Multi-Repo & CI/CD (12 Qs)](../quiz/04-multirepo-and-consul.md) |
| GKE node SAs, transient node pool, 4-part Workload Identity, IAM vs RBAC, node Capacity vs Allocatable (`e2-small` vs `e2-standard-2`), IAP TCP forwarding (`35.235.240.0/20`), VPC Peering, `linux/amd64` manifests | [§10 Production Architecture](10-architecture-multirepo-gke-and-cicd.md) | [GKE, Workload Identity & GCP Networking (13 Qs)](../quiz/05-gke-and-workload-identity.md) |
| Hypothesis-ordered debugging, independent verification (`kubectl` / `gcloud` / `consul`), empty `terraform.tfstate` trap, local dependency readiness checks | [§9 State Surgery](09-state-surgery-drift-and-workspaces.md), [§10 Production Architecture](10-architecture-multirepo-gke-and-cicd.md) | [Debugging, Recovery & Verification (6 Qs)](../quiz/06-debugging-and-verification.md) |
