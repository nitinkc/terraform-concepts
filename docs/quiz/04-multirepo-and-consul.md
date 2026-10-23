---
primary_color: '#007bff'
---

# Quiz — Dependencies, Modules, Multi-Repo & CI/CD Security

<!-- mkdocs-quiz intro -->
The dependency graph (`depends_on` vs implicit edges), module encapsulation and refactoring, `archive_file` vs `local-exec`, Consul KV vs `terraform_remote_state`, root blast-radius boundaries, and GitOps CI/CD security. Reference: [§4 Dependencies & Graph](../reference/04-dependencies-and-graph.md), [§8 Modules & Escape Hatches](../reference/08-data-sources-outputs-and-modules.md), and [§10 Production Architecture](../reference/10-architecture-multirepo-gke-and-cicd.md).

**12 questions.** [Back to all topics](index.md)

<!-- source: session-01 -->
<quiz>
In a multi-repo Terraform setup using Consul KV instead of terraform_remote_state for cross-repo data sharing, what's the main advantage of the Consul approach?
- [ ] It's faster at plan time
- [ ] It avoids needing a backend at all
- [x] It's a deliberate, minimal publish/subscribe contract instead of exposing another repo's entire state file (and all plaintext secrets inside it)
- [ ] It supports encryption while remote_state doesn't
`terraform_remote_state` requires granting the consumer read access to the producer's ENTIRE state file, including internal implementation details and any plaintext secrets stored there. A shared KV contract exposes only the specific non-sensitive fields the producer chooses to publish.
</quiz>

<!-- source: session-01 -->
<quiz>
In a dependency chain repo-A → repo-B → repo-C (each publishing data the next consumes via Consul), repo-C fails with an 'Invalid index' error trying to read a key that's supposed to come from repo-A. What's the most likely root cause?
- [ ] repo-C's own code has a bug
- [x] repo-A hasn't been applied yet, or was applied without the specific resource that populates that key
- [ ] Consul itself is down
- [ ] repo-B is missing a required provider
An 'Invalid index' on a specific nested key (not a connection error) means the JSON structure exists but is missing that branch — almost always because the upstream publisher either hasn't been applied yet, or was applied with a feature flag that skipped creating the resource that populates that key.
</quiz>

<!-- source: session-03 -->
<quiz>
Two `data "consul_keys"` blocks live side by side in the same file. One's path is parameterized by environment (`${local.env_key}`); the other is hardcoded to end in `/default`. The hardcoded one starts failing with an empty-string read. What's the most likely explanation?
- [ ] Consul itself is down
- [x] The hardcoded key was never parameterized by environment when written, while the publishing repo only publishes to environment-specific paths (`/dev`, `/qa`) — a genuine code inconsistency between two adjacent blocks
- [ ] The parameterized key is broken and corrupting the hardcoded one
- [ ] Terraform evaluates key blocks in a fixed, alphabetical order that can cause stale reads
After ruling out terminal/Consul health and active workspace with direct checks, reading the code revealed that one key was parameterized while the structurally identical key next to it was hardcoded to `/default`.
</quiz>

<!-- source: unfiled -->
<quiz>
Two separate Terraform repos both try to create a `google_secret_manager_secret_iam_member` granting the same access — one references the other repo's service-account email via cross-repo data, the other only needs data it already has locally. Which one should actually own the grant?
- [ ] Whichever repo owns the secret container, regardless of data dependencies
- [x] The one that's self-sufficient with data already available in the forward apply order — the one requiring a "backward" reference to a repo that hasn't run yet creates a circular ordering problem
- [ ] Both should keep the resource, for redundancy
- [ ] Whichever repo was written first
If Repo A must run before Repo B, Repo A cannot depend on a service account created by Repo B. The IAM binding belongs in whichever repo already has all required references available in the forward apply sequence.
</quiz>

<!-- source: session-03 -->
<quiz>
A local Consul dev agent (`consul agent -dev`, in-memory only) still has old KV data describing a service account, even though that service account's Terraform state was fully destroyed and rebuilt from scratch. Why?
- [ ] Consul automatically re-validates its data against the real cloud provider
- [x] `terraform destroy` only removes resources managed in that root's state — if a teardown script skips cleaning the KV store or a root is destroyed out of band, stale KV contracts remain until overwritten or explicitly deleted
- [ ] The data must have been manually re-entered
- [ ] Consul data expires automatically after a fixed TTL
Stale KV contracts are a classic cross-repo failure mode: consumers read an obsolete IP or SA email that no longer exists in GCP. Always clean KV contracts during teardown and verify live resources independently.
</quiz>

<!-- source: unfiled -->
<quiz>
A real production Consul deployment and the `consul agent -dev` used in this sandbox both work with identical Terraform HCL. What's actually different between them?
- [ ] Nothing meaningful — dev mode is just a rebranded production mode
- [x] Production Consul is a shared, centrally-reachable cluster with persistent storage and ACL tokens that CI/CD runners read/write concurrently; `-dev` mode is single-machine, in-memory, and unauthenticated
- [ ] Production Consul requires a different provider block syntax
- [ ] `-dev` mode persists data to disk while production mode doesn't
The HCL resource and data blocks are identical — only `CONSUL_HTTP_ADDR` and ACL authentication differ between local dev mode and a production cluster.
</quiz>

<!-- source: reference-04 -->
<quiz>
A `google_project_iam_member` resource sets `member = "serviceAccount:${google_service_account.gsa.email}"`. Should you also add `depends_on = [google_service_account.gsa]` to that block, and when IS `depends_on` genuinely needed?
- [ ] Yes — without `depends_on`, Terraform creates both in parallel and fails
- [x] No — referencing `google_service_account.gsa.email` already creates an implicit dependency edge in the DAG (and reverse destroy order); `depends_on` is only needed when a real-world runtime dependency is invisible to HCL (e.g., waiting for an IAM binding or `google_project_service` API enablement before starting a workload)
- [ ] `depends_on` is required whenever two resources are in different `.tf` files
- [ ] `depends_on` is only used for `data` sources
File names and block order never affect execution order—attribute references build the DAG automatically. Reserve `depends_on` strictly for hidden runtime dependencies where Resource B needs Resource A to finish in the cloud without referencing any of A's attributes.
</quiz>

<!-- source: reference-08 -->
<quiz>
You extract an existing root resource `resource "google_service_account" "gsa"` into a reusable child module `module "backend_sa" { source = "./modules/service_account" }` (where the resource is named `this`). What happens on the next `terraform plan` if you do nothing else?
- [ ] Terraform automatically detects that the `account_id` is identical and updates state seamlessly
- [x] Terraform plans to **destroy** `google_service_account.gsa` and **create** `module.backend_sa.google_service_account.this` because moving a resource into a module prefixes its state address — prevent this with a `moved {}` block or `terraform state mv`
- [ ] Terraform throws a duplicate-resource syntax error during `validate`
- [ ] The child module reads the root module's state automatically
Moving a resource into a child module changes its address from `google_service_account.gsa` to `module.backend_sa.google_service_account.this`. Without a `moved` block or `state mv`, Terraform treats it as deleting the old resource and creating a new one.
</quiz>

<!-- source: reference-08 -->
<quiz>
Both `data "archive_file"` and `null_resource` with `provisioner "local-exec"` step outside standard cloud resource APIs. Why is `data "archive_file"` considered an idiomatic declarative pattern while `local-exec` is treated as a last-resort code smell?
- [ ] `archive_file` runs in the cloud, whereas `local-exec` runs locally
- [x] `archive_file` computes a deterministic `output_md5` / SHA hash during `plan` that feeds directly back into the Terraform dependency graph to trigger downstream updates, whereas `local-exec` runs opaque imperative shell commands whose side effects are untracked in state
- [ ] `local-exec` cannot reference variables or resource attributes
- [ ] `archive_file` encrypts the zip file in state
An escape hatch is safe when its output feeds back into Terraform's declarative graph (`data.archive_file.bundle.output_md5`). `local-exec` mutates the world outside the graph, only re-runs when `triggers` change, and is a major CI/CD security risk.
</quiz>

<!-- source: reference-10 -->
<quiz>
In a GitOps CI/CD pipeline where `terraform plan` runs automatically on every pull request using a service account with state-read access, how can a malicious PR exfiltrate production secrets even if runner internet egress is blocked and CI secret masking is enabled?
- [ ] It can't — blocking egress and enabling CI log masking completely prevents exfiltration during `plan`
- [x] The PR can add a `data "external"` source or module that reads `terraform.tfstate` (or secret env vars), transforms the secret (e.g., `echo $SECRET | base64`), and prints it to build logs — bypassing literal-string secret masking. Mandatory human PR review/approval before running `plan` is the primary defense
- [ ] Secrets in `terraform.tfstate` are encrypted during `plan` and only decrypted during `apply`
- [ ] `terraform plan` never executes `data` sources or module code
Because `plan` must read state and evaluates `data` sources/expressions defined on the PR branch, untrusted PR code executes alongside production state credentials. And because CI log masking relies on literal string matching, `base64` or hex encoding trivially bypasses it. Requiring human approval before the CI pipeline runs `plan` on an untrusted branch is essential.
</quiz>

<!-- source: reference-09 -->
<quiz>
Why do most production multi-environment Terraform architectures prefer separate directories/backend prefixes (`envs/dev/`, `envs/prod/`) over CLI workspaces (`terraform workspace select prod`)?
- [ ] CLI workspaces cannot be used with a GCS remote backend
- [x] Workspaces share a single `backend` block, don't cleanly isolate different GCP projects/credentials per environment, and rely on invisible CLI state (`workspace select`) where a human mistake can accidentally apply to `prod`
- [ ] Workspaces duplicate `.tf` files across environments
- [ ] `terraform.workspace` is deprecated and removed in Terraform 1.7+
While workspaces are convenient for isolated state within a single project or ephemeral feature environments, separate `envs/<env>/` directories make the target project, backend path, and `.tfvars` explicit in the filesystem path and IAM boundary.
</quiz>

<!-- source: reference-10 -->
<quiz>
Which of the following is the strongest architectural signal that a single Terraform root module should be split into multiple independent roots?
- [ ] The directory has more than 5 `.tf` files
- [x] Slow-changing stateful infrastructure (like Cloud SQL databases and GKE clusters) is in the same state file as high-churn application deployments (Helm releases), or two different teams with different IAM privileges need to deploy on independent schedules
- [ ] You want to reuse a block of code twice in the same environment
- [ ] `terraform fmt` takes more than 1 second
A root module defines a state file, an IAM permission boundary, and a blast radius. Splitting stateful foundation infra from high-churn app deployments shrinks blast radius, speeds up `plan` refresh times, and enforces least privilege across teams.
</quiz>

<!-- mkdocs-quiz results -->
