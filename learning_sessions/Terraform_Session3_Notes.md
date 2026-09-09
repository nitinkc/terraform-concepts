# Terraform Tutoring — Session 3 Notes

**Date:** 2026-08-31 (resumed after a ~5 hour pause, following a full destroy/rebuild)
**Topic:** Resuming from a clean-slate teardown, confirming Session 2's fixes
generalize on a fresh apply, a real multi-hypothesis debugging sequence, and
closing out the Kubernetes/Helm provider auth verification deferred across
two prior sessions.
**Method:** Fully hands-on against real GCP, starting from zero (everything
destroyed before this session began).

---

## What Actually Happened (chronological)

1. **Retrieval check on resume** — asked to recall why Session 2 predicted
   2 secrets (not 3) before looking anything up. First answer was vague
   ("keep costs low... if condition for default/np/p"); re-anchored with the
   precise mechanism (only `np` cluster existed, `prod` maps to the never-created
   `p` cluster, so `for_each` over dev/qa/prod could only resolve 2 of 3).
2. **Confirmed a full destroy had happened** — clean slate, not a partial
   state. Chose to rebuild deliberately via the `restore-session2.sh` script
   rather than skip straight to typing commands.
3. **infrastructure/infra re-applied from scratch, verified the fix
   generalizes**: exactly `6 resources added` (2 secrets × 1 version × 1
   consul publish each = 6), `prod` correctly absent from the output on a
   completely fresh apply — not just the run the fix was originally written
   for. Good evidence the guard-propagation fix was general, not a one-off
   patch that happened to work once.
4. **backend/infra plan succeeded** immediately after `infrastructure` was
   re-applied — `app_infra` resolved, `cloudsql_enabled = false` confirmed
   the guarded-degradation design (from Session 2's comparison) behaving
   exactly as reasoned, live.
5. **Deliberate decision point**: apply `backend/infra` now in mock-data
   mode (closes the still-outstanding Kubernetes/Helm auth verification,
   free) vs. apply `cloudsql/infra` first (costs more, more realistic).
   **Chose mock-data mode first** — correctly prioritized closing a
   twice-deferred item over completeness.
6. **Real, multi-step debugging incident** — `terraform apply` in
   `backend/infra` failed on the exact same `app_infra` line that had just
   resolved cleanly in `plan` moments earlier. Three hypotheses tested and
   ruled out in order, each with actual verification rather than assumption:
   - **H1: different terminal/environment, `CONSUL_HTTP_ADDR` not
     inherited.** Checked `pgrep -f "consul agent -dev"` (running) and
     `consul kv get` directly on the exact key (data present, correct JSON).
     Ruled out.
   - **H2: wrong Terraform workspace** (`default` instead of `dev`, which
     would map to the never-published `prod`/`p` branch). Checked
     `terraform workspace show` → `dev`, correct. Ruled out.
   - **H3 (found by reading code, not guessing further)**: the
     `data "consul_keys" "remote_outputs"` block's `"infrastructure"` key
     had a **hardcoded path ending in `/default`**, never parameterized by
     environment — unlike the `"cloudsql"` key right below it in the same
     block, which *was* correctly parameterized
     (`${contains(...) ? terraform.workspace : "dev"}`). Since
     `infrastructure/infra` only ever published to `/dev` and `/qa`
     (Session 2's Option B), this read was doomed regardless of workspace,
     Consul health, or terminal — a genuine bug in the repo's own code, not
     a usage mistake. **Fixed** by parameterizing with the already-computed
     `local.infra_env_key`, matching the `cloudsql` key's pattern.
7. **Fix verified**: `terraform plan` succeeded cleanly, exit code 0, no
   error, after the one-line path fix.
8. **First real Kubernetes-facing `apply`** in `backend/infra` — succeeded.
9. **Kubernetes/Helm provider auth chain verified end-to-end, independently**
   — not just via Terraform's own success message:
   - `gcloud container clusters get-credentials` + `kubectl config
     current-context` — real kubeconfig context created.
   - `kubectl get ns | grep acme-sampleapp` — real namespace
     (`acme-sampleapp-backend-dev`) confirmed `Active`.
   - `kubectl get sa -n ...` — found the K8s ServiceAccount
     (`acme-sampleapp-backend-sa`).
   - **Correctly distinguished** (after one clarifying nudge) that the K8s
     ServiceAccount and the GCP IAM service account are two separate
     identities linked by annotation, not by name-matching.
   - `kubectl get sa ... -o jsonpath='{.metadata.annotations}'` — confirmed
     the actual Workload Identity annotation
     (`iam.gke.io/gcp-service-account: sa-backend-dev@...`) present and
     correct, verified via `kubectl` independently of Terraform's own state.

---

## Key Mechanics Learned (for quick recall later)

- **A fix that resolves one instance of a bug should be re-tested on a
  fresh apply, not just trusted** — this session deliberately re-verified
  Session 2's guard-propagation fix from a full teardown, not just assumed
  it still worked.
- **Inconsistent parameterization between structurally similar code blocks
  is a classic, easy-to-miss real bug pattern** — the `"cloudsql"` key was
  parameterized by environment; the `"infrastructure"` key, right next to
  it, was hardcoded. Both looked equally plausible at a glance; only one
  was correct.
- **When multiple plausible hypotheses exist, test them in order and rule
  each one out with direct evidence** rather than jumping straight to a
  code change: environment/terminal mismatch → workspace mismatch → actual
  code bug, each checked with a concrete command, not assumed.
- **Workload Identity is two separate identities linked by annotation, not
  by name.** A Kubernetes ServiceAccount and a GCP IAM service account can
  have completely different names — `iam.gke.io/gcp-service-account` on the
  K8s SA's annotations is the actual link, and it's worth verifying
  directly via `kubectl`, not just trusting Terraform's `apply` success.
- **Terraform state's confirmation isn't the same as independent
  verification** — `kubectl` (a completely separate tool reading the same
  live cluster) confirming the namespace, service account, and annotation
  all matched is stronger evidence than the `apply` log alone.

## What's Next (Session 4)

1. `cloudsql/infra` still hasn't been applied this session — decide
   whether to add a real Cloud SQL instance (switches `cloudsql_enabled` to
   `true`, real cost) or continue building out `frontend/infra` first while
   staying in mock-data mode.
2. `frontend/infra` hasn't been touched yet — natural next step now that
   `backend/infra` is confirmed working end to end.
3. Good candidate for a *transfer* check (Gate 4): give a fresh, different
   for_each-guard scenario (not the one already taught in Session 2) and
   see if the pattern gets applied independently this time, without
   re-teaching it.
4. Also worth verifying: does the same hardcoded-path bug class exist
   anywhere else in the sandbox? Worth a deliberate grep-and-check pass
   across `frontend/infra` and `cloudsql/infra` before assuming they're
   clean — directly applying this session's "don't assume, verify" lesson.
5. **Cost reminder**: `np` GKE cluster + 2 Secret Manager secrets + backend
   namespace/resources are all currently live and billing. Same
   destroy/restore workflow applies going into any future pause.
