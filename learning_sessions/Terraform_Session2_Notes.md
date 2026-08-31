# Terraform Tutoring — Session 2 Notes

**Date:** 2026-08-30 (continued from Session 1, same day)
**Topic:** Live GKE cluster creation, variable precedence, real incident
diagnosis (orphaned resources, transient node pools), workspaces hands-on,
cross-repo dependency chain debugging, guard-propagation pattern.
**Method:** Fully hands-on against real GCP (`my-devops-journey-502420`),
multiple real incidents diagnosed and fixed live, not staged examples.

**PAUSED HERE — mid-verification.** Last action: applied a 3-file patch to
`infrastructure/infra` (`main.tf`, `secrets.tf`, `outputs.tf`) and asked for a
prediction (2 secrets created — dev+qa — vs 3) before running `terraform
apply`. **The actual apply output was never seen** — this is the very first
thing to check when Session 3 resumes.

---

## What Actually Happened (chronological)

1. **Variable precedence, live-tested for real.** Edited `variables.tf`'s
   `default` for `enable_gke_np` to `true`, ran `apply`, got `0 added` —
   confusing at first. Correctly diagnosed (with one nudge) that
   `terraform.tfvars` still had `enable_gke_np = false` and was overriding
   the default. Full precedence order established for recall:
   `default` < `terraform.tfvars` < `*.auto.tfvars` < `-var-file` <
   `-var` < `TF_VAR_*` env vars (highest).
2. **Real incident #1 — missing default Compute Engine service account.**
   `terraform apply` on `sample-program` (GKE) failed:
   `Failed precondition ... verify if principal exists`. Diagnosed:
   `google_container_node_pool`'s implicit dependency on the default
   Compute SA, which either hadn't propagated yet after enabling the API,
   or (confirmed via `gcloud iam service-accounts list` returning
   **0 items**) never existed in this project at all. **Fix**: added a
   dedicated, minimal-scope node service account
   (`google_service_account.node` + 4 `google_project_iam_member` role
   grants: logWriter, metricWriter, monitoring.viewer,
   artifactregistry.reader) instead of depending on the default SA —
   matches the same pattern `backend/infra`/`frontend/infra` already use
   for their own GSAs, for the same reason (security + reliability, not
   just fixing the immediate error).
3. **Real incident #2 — transient node pool gotcha.** After incident #1's
   fix, error moved to `google_container_cluster.main` itself, same root
   cause. **Learned mechanic**: `remove_default_node_pool = true` still
   requires GKE to briefly create a transient initial node pool during
   cluster creation (deleted right after) — and that transient pool uses
   the `node_config` block on `google_container_cluster` directly, not the
   separate `google_container_node_pool` resource. Fix: added a matching
   `node_config` (same dedicated SA) directly on the cluster resource too.
4. **Real incident #3 — orphaned/drifted resource.** After a partial-failure
   `apply` (from before incident #2's fix), GCP had a half-created
   `sample-program-np` cluster that Terraform's state had no record of.
   Next `apply` failed: `Already exists`. **Correctly reasoned toward the
   right diagnostic question when nudged**: `import` is right when the real
   resource is healthy and just missing from state; wrong when the resource
   itself might be broken/incomplete (as here, since creation had failed
   partway through). Decision framework established: **the deciding factor
   is whether the resource holds anything irreplaceable** — a broken,
   empty, minutes-old lab cluster has nothing to preserve, so
   delete-and-recreate beats reconciling. Fixed via
   `gcloud container clusters delete` + clean re-apply.
5. **First real success**: `np` GKE cluster created and verified live —
   confirmed via `terraform output gke_clusters_created` (`["np"]`) and
   `consul kv get` on the `sample-program` key, showing the actual
   `gke.host`, `cluster_ca_certificate`, `name`, `project` fields correctly
   populated — field names cross-checked and matching exactly what
   `backend/infra`'s `providers.tf` expects.
6. **Workspaces, hands-on for the first time.** Checked `terraform workspace
   show` (`default`) in `backend/infra`. Since only the `np` cluster exists
   and `local.p_or_np = workspace == "default" ? "p" : "np"`, correctly
   reasoned the need to switch workspaces. Before creating `dev`, correctly
   predicted `local.is_review_env` would evaluate `true` on the `dev`
   workspace (`workspace != "default"` AND `!var.static_env`, with
   `static_env` unset/false by default) — correct, with full reasoning
   chain shown.
7. **Real design gap surfaced (not a mistake — genuinely undocumented
   repo behavior)**: `local.static_envs = ["dev","qa"]` in `backend/infra`
   is **never actually cross-referenced against `terraform.workspace`** —
   it's purely descriptive; `var.static_env` is a separate, manually-set
   boolean nothing enforces consistency with. Flagged as a real "naming
   conventions aren't automatically enforced" lesson, good interview/lead
   conversation material. Decision made: set `static_env = true` in
   `backend/infra/terraform.tfvars` for predictable behavior rather than
   testing the review-env/random-suffix path this session.
8. **Cross-repo dependency chain, real failure**: `backend/infra plan`
   failed on `app_infra = jsondecode(data.consul_keys...).outputs...` —
   `EOF` error, because `data.consul_keys.remote_outputs.var.infrastructure`
   was `""` (empty string) — `infrastructure/infra` had never been applied.
   Initial guess ("no remote consul?") was wrong — Consul itself was
   already proven working minutes earlier via the `program` key resolving
   correctly. Correct root cause: **that specific Consul key** had simply
   never been published to, since its publisher repo hadn't run yet.
9. **Design comparison, genuinely good conceptual moment**: compared
   `cloudsql.tf`'s guarded pattern (`try(..., "")` + `!= ""` check before
   `jsondecode`, feeding a nullable `cloudsql_enabled` flag with a real
   mock-data fallback) against `main.tf`'s unguarded `app_infra` line (which
   directly errors if the key is missing). Established: this isn't
   inconsistent code — it's **deliberate**. Cloud SQL is a genuinely
   optional dependency (the app has a real fallback: mock mode). SSO/auth
   is a **hard prerequisite** with no meaningful fallback — failing fast and
   loud is the *correct* design there, not a shortcut. Good "why is it
   built this way" material for lead conversations.
10. **Applied `infrastructure/infra`** to fix the actual missing dependency
    — hit a *third* instance of the same underlying issue class: `for_each`
    over `["dev","qa","prod"]` tried to resolve the `"prod"` → `"p"` branch,
    which doesn't exist (only `np` cluster was created this session).
    Correctly diagnosed root cause on the second attempt (initially guessed
    "default workspace," corrected to "no `terraform.workspace` in this
    repo at all — it's the literal string `prod` in the `for_each` list that
    maps to the missing `p` cluster").
11. **Decision point, explicitly deliberated**: create the `p` cluster too
    (Option A, more realistic, costs more) vs. patch `infrastructure/infra`
    to gracefully skip environments whose upstream cluster doesn't exist yet
    (Option B, cheaper, lab-appropriate). **Chose Option B.**
12. **Implemented the guard-propagation pattern** — the actual lesson here:
    a guard only protects what it *directly* wraps. Filtering
    `program_gcp_by_env` in `main.tf` alone wasn't sufficient — `secrets.tf`
    (2 resources) and `outputs.tf` (1 resource) all independently did
    `for_each = toset(local.environments)` (the *unfiltered* 3-item list)
    and then indexed the now-filtered map directly, which would have just
    moved the same "Invalid index" error one file downstream. Fixed by
    introducing `local.available_environments = keys(local.program_gcp_by_env)`
    and switching all three downstream `for_each` loops to use it. Noted
    (correctly, unprompted context established) that `iam.tf`'s existing
    `for_each` loops were already correctly guarded independently (its own
    null-check on `backend_sa_email_by_env`), so no change was needed there.
13. **Session paused right before verifying the fix** — predicted 2 secrets
    created (dev + qa) vs 3, `apply` was run, but the actual output was
    never reported back. **First thing to check in Session 3.**

---

## Key Mechanics Learned (for quick recall later)

- **Variable precedence** (low → high): `default` in `variables.tf` <
  `terraform.tfvars` < `*.auto.tfvars` < `-var-file` < `-var` <
  `TF_VAR_*` env vars. `.tfvars` files silently win over edited defaults —
  a common real-world gotcha.
- **GKE node pools need an explicit `service_account`** — the default
  Compute Engine SA isn't guaranteed to exist (propagation delay, or never
  created at all depending on project history/policy), and even when it
  does exist it's overly-broad (Editor-level). Dedicated, minimal-scope SA
  is the correct pattern, not just a workaround.
- **`remove_default_node_pool = true` still needs `node_config` on the
  cluster resource itself** — a transient initial node pool is created
  during cluster creation regardless, and it uses the cluster's own
  `node_config`, not the separate `google_container_node_pool`'s.
- **`import` vs delete-and-recreate for orphaned/drifted resources**: import
  when the real resource is healthy and simply untracked; delete-and-recreate
  when the resource's own integrity is in doubt (e.g. a failed partial
  creation) and nothing irreplaceable would be lost.
- **Guarding (`try()`/conditional filtering) is a design decision, not a
  default best practice** — whether to fail fast or degrade gracefully
  depends on whether the missing dependency is one the system can
  meaningfully operate without (Cloud SQL: yes, has mock-data fallback.
  SSO/auth: no, hard prerequisite).
- **A guard only protects what it directly wraps** — every downstream
  consumer of a filtered value needs to either use the same filtered
  key-set for its own `for_each`, or carry its own independent guard, or
  the same class of error just resurfaces one file later.
- **Workspaces**: `terraform workspace show`/`new`/`select` create genuinely
  separate state per workspace. `terraform.workspace` is just a string —
  any logic keyed off it (like `local.is_review_env`) is only as correct as
  the code that reads it; nothing enforces naming conventions like
  `static_envs = ["dev","qa"]` automatically matching real workspace names.

## Real Incidents Diagnosed This Session (good interview/lead-conversation material)

1. Missing/non-existent default Compute Engine service account → dedicated
   node SA pattern.
2. Transient node pool during `remove_default_node_pool` cluster creation →
   `node_config` needed on both the cluster and the node pool resources.
3. Orphaned drifted resource after a partial-failure apply → informed
   import-vs-recreate decision, not a reflexive default.
4. Missing upstream Consul publish (`infrastructure` not yet applied) →
   correctly traced to the specific unpublished key, not a Consul-wide issue.
5. `for_each` over an environment list hitting one entry whose upstream data
   doesn't exist yet (`prod` → `p` cluster) → guard-propagation fix across 3
   files.

## What's Next (Session 3 — resume point)

1. **First**: check the result of the `infrastructure/infra apply` that was
   running when the session paused. Confirm whether 2 secrets (dev+qa) were
   created, matching the prediction, or something unexpected happened.
2. Re-run `backend/infra plan` — `app_infra` should now resolve correctly
   since `infrastructure/infra` has been applied. Confirm the SSO secret
   access grant resolves.
3. `cloudsql/infra` hasn't been applied yet this session — `backend/infra`
   will still hit `cloudsql_enabled = false` / mock-data mode until it is.
   Decide whether to apply a real (small) Cloud SQL instance or continue in
   mock mode for now (Cloud SQL costs more than the other resources so far
   — worth a deliberate decision, not a default).
4. Once `backend/infra` fully applies, verify the Kubernetes/Helm provider
   actually authenticates against the live `np` cluster (`kubectl get ns`
   showing the real namespace) — this was flagged as Session 2's original
   goal and hasn't been directly tested yet.
5. Continue into `frontend/infra` once `backend/infra` is confirmed working
   end to end.
6. Remember: both `p` and `np` GKE-enable flags conversation — currently
   only `np` was actually created (Option B chosen instead of creating
   `p`). Revisit whether `p` is ever needed, or whether the sandbox stays
   `np`-only for cost reasons going forward.
7. **Cost reminder**: `np` GKE cluster is currently live and billing. If
   pausing for an extended period (this pause is ~5 hours), consider
   whether to `terraform destroy` in `sample-program/infra` and re-apply
   next session, or leave it running — a single e2-small spot node is cheap
   but not free. Worth a conscious choice, not a default.
