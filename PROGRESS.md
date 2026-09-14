# Terraform Learning Progress

**Updated:** 2026-09-14  
**Goal:** Become an expert Terraform developer through theory, isolated labs, real GCP practice, and production-style multi-root troubleshooting.

## Current Position

The learner has progressed from zero Terraform experience to functional hands-on ability with providers, state, plans, GCP resources, workspaces, Consul contracts, GKE, Helm, and Workload Identity. The strongest evidence is not document reading: three sessions used real GCP infrastructure, real partial failures, fresh rebuilds, and independent verification with Consul and `kubectl`.

Current level is best described as **early intermediate overall**, with stronger pattern recognition in variable precedence and debugging. Expert-level readiness still requires independently designing unfamiliar modules, testing changes, operating remote state and CI/CD, completing the entire Acme dependency graph, and demonstrating security/production judgment repeatedly.

## Completed Learning Foundation

- 19-page Terraform theory path plus glossary and concept index.
- Local exercises covering resources/state, variables, references, dependencies, lifecycle, data sources, and version constraints.
- GCP exercise covering provider/backend structure, networking, compute, data sources, outputs, locals, and a reusable VM module.
- Six-topic, 33-question quiz linked to incidents from the hands-on work.
- MkDocs site and GitHub publishing workflow.

## Acme Sandbox Implemented

The main exercise models five independently stateful roots coordinated through Consul:

| Root | Implemented scope | Hands-on status |
|---|---|---|
| `sample-program/infra` | Reusable VPC, GKE, and DNS modules; dedicated least-privilege node SA; Artifact Registry; Consul outputs | Applied and rebuilt successfully; `np` cluster verified |
| `infrastructure/infra` | Environment-filtered Secret Manager resources, versions, IAM, Consul publishing | Applied from a clean slate; dev/qa guard behavior verified |
| `cloudsql/infra` | IAM-auth Cloud SQL, database/user plumbing, grant/revoke function outputs | Code exists; no recorded successful hands-on apply |
| `backend/infra` | Consul reads, namespace, GSA/KSA Workload Identity, IAM/RBAC, optional Cloud SQL bridge, Helm release | Applied in dev/mock mode; namespace and identity annotation verified with `kubectl` |
| `frontend/infra` | Namespace, identity, RBAC, static IP/DNS, Helm release | Code exists; no recorded hands-on apply |

Additional operational work now present:

- Safe `restore-session.sh` with plan-first behavior, missing-state refusal, Consul republishing, GKE node readiness check, failed-Helm repair, and graph generation.
- Read-only `verify-session.sh` for tools, ADC, Consul contracts, state presence, GKE, Kubernetes, Helm, and optional refresh plans.
- Reverse-order `destroy-all.sh`.
- Minimal backend health application and Dockerfile plus Artifact Registry support.
- Terraform dependency graphs and a restore-session GCP architecture diagram.

## Demonstrated Competencies

- Correctly predicted plans and reasoned through provider fallback behavior.
- Understood that `init` installs tooling while `apply` changes infrastructure/state.
- Diagnosed partial apply behavior and predicted idempotent recovery.
- Corrected the misconception that data sources remain usable from stale state.
- Used workspaces and diagnosed `terraform.tfvars` precedence over defaults.
- Diagnosed missing default Compute Engine SA and implemented a dedicated node SA.
- Learned the transient GKE node-pool requirement with `remove_default_node_pool`.
- Made an evidence-based import-versus-recreate decision for an orphaned lab cluster.
- Traced missing and malformed Consul contracts across independent roots.
- Fixed environment guard propagation across downstream `for_each` consumers.
- Found and fixed a hardcoded Consul environment path by testing hypotheses.
- Verified Helm/Kubernetes deployment and Workload Identity independently with `kubectl`.

## Open Gaps and Risks

### Hands-on milestones

- Apply and verify `cloudsql/infra`, then prove the backend switches from mock mode to IAM-authenticated Cloud SQL.
- Apply and verify `frontend/infra`, including DNS/IP, ingress, service routing, and frontend-to-backend behavior.
- Run and record a complete five-root build, verification, drift check, and reverse teardown.
- Independently solve a new `for_each` guard scenario to prove transfer rather than recall.

### Terraform expertise gaps

- Deepen `count`, `for_each`, `dynamic`, module composition, and refactoring with `moved`/`import` blocks.
- Practice remote GCS state, locking/concurrency behavior, state security, recovery, and migration from local state.
- Add CI checks for formatting, validation, linting/security, plans, and controlled applies.
- Add automated module/contract tests and negative tests for missing Consul fields.
- Practice provider aliases, multi-project deployments, module versioning, policy controls, and upgrade workflows.
- Perform a deliberate IAM, secrets, network exposure, encryption, and cost review.

### Repository quality debt

- `terraform fmt -check -recursive` fails on 12 pre-existing files: eight basics `main.tf` files plus Acme frontend `iam.tf`/`main.tf`, VPC module `main.tf`, and sample-program `variables.tf`.
- `backend/infra/variables.tf` still contains a TODO to replace the sample operations group.
- Root/Acme documentation says application source is absent, but a minimal `backend/app` health service now exists; documentation needs reconciliation.
- Current live GCP resource status is unknown from source alone. Run `./verify-session.sh` before assuming resources still exist.
- Full `terraform validate` for every root has not been re-run in this review because provider initialization/live credentials may be required.

## Next Recommended Milestones

1. **Quality baseline:** format intentionally, initialize each root, run `terraform validate`, and record clean results without applying.
2. **Cloud SQL vertical slice:** plan, apply with approval, verify IAM database access, then verify backend behavior without mock mode.
3. **Frontend vertical slice:** audit Consul paths first, apply, and independently verify ingress/DNS and `/api` routing.
4. **End-to-end exercise:** rebuild all five roots from empty lab state, run `verify-session.sh --plans`, document failures, and destroy in reverse order.
5. **Production state exercise:** migrate a disposable root from local to GCS state and rehearse locking, backup, import, and recovery.
6. **Automation:** add CI for `fmt`, `validate`, docs, security/lint checks, and plan artifacts.
7. **Expert capstone:** design a new environment or service root from requirements, including module boundaries, state ownership, contracts, IAM, tests, rollout, and incident recovery.

## Evidence Sources

- `docs/sessions/session-01.md` through `session-03.md`
- `docs/sessions/learner-state.md`
- Acme `README.md`, `RUNBOOK.md`, Terraform roots, Helm charts, and helper scripts
- Recent repository history through commit `139a8fd`

## Update Rules

- Record only demonstrated work as completed; distinguish implemented code from live-verified behavior.
- Add dates and commands/results for new validation evidence.
- Move milestones to completed only after independent verification, not merely a successful `terraform apply` message.
- Keep detailed narratives in `docs/sessions/`; keep this file as the concise current-state dashboard.
