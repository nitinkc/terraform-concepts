# Terraform Tutoring — Session 1 Notes

**Date:** 2026-08-30
**Topic:** Core mechanics — provider config, `init`/`plan`/`apply`/state, `resource`
vs `data`, partial-apply behavior, cross-repo Consul publish/consume.
**Method:** Live, hands-on against real GCP (`my-devops-journey-502420`) using the
`acme-sampleapp` sandbox, not just reading code.

---

## What Actually Happened (chronological)

1. Confirmed `gcloud auth application-default login` writes a refresh token to
   `~/.config/gcloud/application_default_credentials.json` — read automatically
   by Terraform's `google` provider and any Google client library, no extra
   config needed. Access tokens expire hourly; refresh token doesn't (until
   revoked). Corrected: "some timeout" → precise mechanism.
2. Ran `terraform init` in `sample-program/infra` — confirmed it downloads
   providers into `.terraform/` + writes `.terraform.lock.hcl`, and does
   **not** create `terraform.tfstate`. State only gets written by the first
   real `apply`/`refresh`.
3. **Live experiment**: commented out the `provider "google" {}` block
   entirely. `init` still succeeded (provider *plugin* download is controlled
   by `required_providers` in `versions.tf`, unrelated to the config block).
   `plan` still succeeded too, once a confound was ruled out (missing
   `terraform.tfvars` was independently causing a variable prompt). Root
   cause: every resource in `modules/vpc`, `modules/gke`, `modules/dns` sets
   its own explicit `project = var.project_id` — so the provider block's
   `project` was never actually being used as a fallback by anything.
   **Key rule discovered**: provider-block `project`/`region`/`zone` are
   fallback defaults only, overridden per-resource whenever a resource sets
   its own.
4. Corrected a real misconception: **`data` blocks do not persist from
   state if the underlying real resource is deleted.** They re-query the
   live API on every `plan`/`apply`; if the real object is gone, the next
   plan errors (`Failed to find resource`), it doesn't silently return a
   stale cached value. Confirmed why `data "google_client_config" "default"`
   (used for the Kubernetes/Helm provider's auth token) is a `data` source
   specifically: access tokens expire hourly, and only a `data` source
   guarantees a fresh read on every run — a `resource` would only refresh on
   `apply`, and only if Terraform detected drift.
5. **Correctly predicted, unprompted**, the full 7-resource plan for
   `sample-program/infra` (`consul_keys`, `google_dns_managed_zone`,
   `google_compute_network`, `google_compute_router`,
   `google_compute_router_nat`, and 2× `google_compute_subnetwork` via
   `for_each`) — correctly excluded the GKE cluster/node pool since both
   enable flags default `false`.
6. **Real incident, real diagnosis**: `terraform apply` on `sample-program`
   partially failed — 6/7 resources succeeded (VPC, DNS zone, router, NAT,
   both subnets), `consul_keys.publish_outputs` failed with
   `connection refused` on `localhost:8500` (no local Consul agent running).
   **Correctly reasoned, unprompted**, that the 6 successful resources were
   already durably written to state — **`apply` is not transactional**;
   each resource commits to state as it individually succeeds, not as one
   atomic batch. This is why the re-run only needed `1 to add`, not
   `7 to add` — direct, observed proof of state-tracking/idempotency, not
   just theory.
7. Correctly reasoned (from microservices/distributed-systems background)
   that a **real Consul deployment would be a shared, centrally-reachable
   service** (its own cluster, stable network address, real ACL tokens) —
   the local `consul agent -dev` here is a single-machine stand-in for
   exactly that, mechanically identical HCL either way.
8. Fixed the Consul gap (installed + started `consul agent -dev`), re-ran
   `plan` → correctly predicted `1 to add, 0 to change, 0 to destroy` →
   confirmed by actual output.
9. Verified the actual published Consul value via `consul kv get` — saw
   `{"outputs":{"gcp":{"us_central1":{}}}}`, correctly reasoned this was
   because `local.gke_clusters_enabled` (filtered from `enable_gke_p`/`np`,
   both `false`) was an empty map, so the `for_each`-built JSON object had
   no keys at all.
10. Attempted `backend/infra` `plan` next — first guessed the failure would
    surface at `kubernetes_namespace_v1`. **Actual failure was earlier**:
    `Invalid index` on `local.program_gcp = jsondecode(...).us_central1[local.p_or_np]`,
    because `us_central1` was `{}` — no `"p"` key existed since no GKE
    cluster had been created yet. Correctly diagnosed the root cause
    (empty map, not a Terraform bug) once shown the error.
11. Session ended with `enable_gke_p = true` and `enable_gke_np = true` set,
    about to apply real GKE clusters — continues into Session 2.

---

## Key Mechanics Learned (for quick recall later)

- **`init` vs `apply`**: `init` = tooling/dependencies only, safe to rerun
  anywhere, never touches real infra or state. `apply` = the only thing that
  creates/modifies real infrastructure and writes state.
- **Provider block config is a fallback, not a mandate** — any resource that
  sets its own `project`/`region`/`zone` ignores the provider block's value
  entirely.
- **`resource` = Terraform-owned, full lifecycle, drift-checked on `plan`.**
  **`data` = read-only, re-fetched live every run, errors if the real thing
  is gone** (never silently stale).
- **`apply` commits per-resource, not atomically** — a failure partway
  through leaves everything before it as real, state-tracked infrastructure.
  Re-running `plan` after a partial failure only shows the remainder.
- **Cross-repo Consul publish/consume is a real dependency chain** — if the
  upstream repo hasn't published real data (e.g. no GKE cluster exists yet),
  the downstream repo fails fast and specifically at the point it tries to
  index into the missing data, not at some later unrelated resource.

## Corrections Made This Session

- "Data blocks persist from state even if the real resource is deleted" →
  corrected: they re-query live, every run.
- Used "import" when meaning "explicit dependency (`depends_on`)" —
  terminology slip, self-corrected once flagged. `import` is an unrelated
  mechanism (bringing an existing real resource under management).
- Operational (not conceptual) miss: forgot to `cp terraform.tfvars.example
  terraform.tfvars` twice before running `plan` — not a Terraform
  misunderstanding, just a setup step to build into habit.

## What's Next (Session 2)

- Finish applying `sample-program` with both GKE clusters enabled (cost
  reminder: destroy both when done for the day).
- Once `p`/`np` clusters exist and `sample-program` republishes to Consul,
  re-run `backend/infra plan` — confirm `local.program_gcp` resolves.
- First real look at the `kubernetes`/`helm` provider blocks actually
  authenticating against a live cluster (`data.google_client_config.default`
  → token → provider config chain, tested live this time, not just read).
- Continue into `count`/`for_each` at greater depth (the `count=0` gap from
  the original baseline diagnostic, plus real `for_each` usage already seen
  in `sample-program`'s `module "gke"` and `google_project_iam_member` in
  `backend/infra/iam.tf`).
