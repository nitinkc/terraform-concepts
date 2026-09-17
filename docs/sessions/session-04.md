# Terraform Tutoring — Session 4 Notes

**Date:** 2026-09-17
**Topic:** Safe recovery from a missing local Consul dependency and misleading empty Terraform state files.
**Method:** Read-only state and live-resource reconciliation, approved restore applies, independent verification, a complete teardown, and lifecycle-script hardening.

---

## What Actually Happened

1. A saved Terraform plan attempted to create only `consul_keys.publish_outputs`, but failed because no process was listening at `127.0.0.1:8500`.
2. `verify-session.sh` confirmed the underlying prerequisite was absent: the Consul CLI was not installed.
3. Source tracing found that `restore-session.sh` launched `consul agent -dev` without first checking that the binary existed, then reported a fresh start without verifying agent readiness.
4. The initial verification found no Ready GKE nodes. Read-only follow-up showed the node pool was `RUNNING`, configured for one `e2-standard-2` Spot node, and the node subsequently became `Ready`; this was a transient capacity/startup condition rather than Terraform configuration drift.
5. Both infrastructure/default and backend/dev had state files but `terraform state list` returned no resources. The existing missing-file guard therefore did not protect against recreation from an empty state.
6. Live reconciliation found no matching SSO secrets, backend GCP service account, backend namespace, or Helm release. The Artifact Registry repository exists but contains no backend image, so backend deployment cannot become healthy until an image is built and pushed.
7. The restore script was hardened to require its tools before Terraform, wait for Consul readiness, report startup logs on failure, and reject empty state unless bootstrap is explicit.
8. Consul was installed from HashiCorp's Homebrew tap and its leader/member health was verified. Reviewed plans then restored the sample-program contract (1 add) and infrastructure dev/qa secrets and contracts (6 adds), with no changes or destroys.
9. Enabling the Cloud Build API succeeded, but image submission was blocked because the active account lacks `iam.serviceAccounts.get`. Docker Desktop was used instead; the first push contained only an ARM-compatible manifest and GKE reported `no match for platform in manifest`.
10. The image was rebuilt and pushed explicitly for `linux/amd64`. The waiting Helm install recovered without replacement, and the reviewed backend plan completed with 9 adds, no changes, and no destroys.
11. `verify-session.sh --plans` finished with 0 failures and 0 warnings: all Consul contracts existed, the node and backend pod were Ready, Helm was deployed, and all three checked Terraform roots had no changes.
12. The original `destroy-all.sh` removed the tracked GCP and Kubernetes resources in reverse order, but left stale Consul contracts and empty state files; its `-s` option also skipped whole roots without proving they were empty.
13. The lifecycle scripts were redesigned around the real learning goal: plain restore after a recorded clean destroy, all-workspace reverse teardown, automatic backend image recreation, stale-contract cleanup, and create/destroy summaries split into potentially billable and no-direct-charge Terraform resource counts.

## Demonstrated Concepts

- A state file's existence is not evidence that it owns resources; inspect `terraform state list`.
- A provider-backed local dependency must be health-checked before planning or applying dependent resources.
- Kubernetes readiness is time-sensitive, especially with Spot nodes; verify immediately before Helm operations.
- Reconcile state against live APIs before choosing import versus intentional bootstrap.

## Remaining Milestones

- Apply and verify the Cloud SQL vertical slice, then prove the backend switches from mock mode to IAM-authenticated database access.
- Apply and verify the frontend vertical slice.
- Decide whether the newly enabled Cloud Build API is needed for later labs or should be disabled during a separately approved cleanup.
