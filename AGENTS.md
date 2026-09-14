# Agent Guide

## Purpose

This repository is a hands-on Terraform learning workspace. Optimize changes for the long-term goal: become an expert Terraform developer who can design, implement, debug, secure, and explain production-style infrastructure.

## Start Here

1. Read `PROGRESS.md` for current status, verified achievements, and next milestones.
2. Read `README.md` for the learning path.
3. For Acme work, read `acme-sampleapp-multirepo-sandbox-elaborate/README.md` and `RUNBOOK.md` before changing or applying infrastructure.
4. Use `docs/theory/concept-index.md` to connect code changes to theory, labs, and quizzes.
5. Use `docs/sessions/learner-state.md` for detailed competency evidence; session files are historical narratives.

## Repository Areas

- `01-basics/`: isolated local-provider exercises; no cloud cost.
- `02-gcp-terraform/`: focused GCP root module and reusable VM module.
- `acme-sampleapp-multirepo-sandbox-elaborate/`: main production-style exercise with five independent Terraform roots.
- `docs/`: theory, labs, quizzes, runbooks, and learning-session evidence.

## Acme Architecture Rules

- Treat every `*/infra/` directory as an independent root with its own state and lifecycle.
- Never copy, delete, or combine state files across roots.
- Preserve the dependency order: `sample-program` → `infrastructure`/`cloudsql` → `backend` → `frontend`.
- Preserve reverse destroy order.
- Cross-root integration uses explicit JSON contracts in Consul, not `terraform_remote_state`. When changing a published field or key path, audit every writer and reader.
- `sample-program` owns VPC, GKE, DNS, and Artifact Registry; `infrastructure` owns shared SSO secrets; `cloudsql` owns the database; `backend` and `frontend` own their Kubernetes/Helm deployments.
- Keep optional dependencies guarded and hard prerequisites fail-fast. Propagate filtered key sets to every downstream `for_each` consumer.
- Preserve least-privilege service accounts and the GKE Workload Identity annotation linking Kubernetes and Google service accounts.

## Safety

- The Acme sandbox creates billable GCP resources. Do not run `terraform apply`, `terraform destroy`, `restore-session.sh --bootstrap`, or other infrastructure-changing commands without explicit user approval.
- Prefer `terraform plan`, `terraform validate`, `terraform fmt -check`, and `./verify-session.sh` for read-only verification.
- Never treat missing state as permission to recreate resources. Recover or import healthy existing resources first.
- Never commit credentials, state, plan files, generated secrets, or real organization identifiers.
- Local Consul uses unauthenticated in-memory dev mode and is suitable only for this learning machine.

## Change Workflow

1. Identify the affected Terraform root and its upstream/downstream Consul contracts.
2. Explain the Terraform concept being practiced and the expected plan before editing.
3. Make the smallest idiomatic change, preserving existing provider and module patterns.
4. Run formatting checks and targeted validation. Do not silently rewrite unrelated learning exercises.
5. For live infrastructure, inspect the plan before apply and independently verify results with GCP, `kubectl`, Helm, or Consul tools.
6. Update `PROGRESS.md` when a milestone, gap, incident, validation result, or next step changes.
7. Add a session note when work includes a substantive hands-on learning session; update `docs/sessions/learner-state.md` only from demonstrated evidence.

## Verification Commands

```bash
terraform fmt -check -recursive

# In a selected Terraform root after initialization:
terraform validate
terraform plan

# Acme shell syntax:
for script in acme-sampleapp-multirepo-sandbox-elaborate/*.sh; do bash -n "$script"; done

# Read-only live checks; --plans refreshes live state:
cd acme-sampleapp-multirepo-sandbox-elaborate
./verify-session.sh
./verify-session.sh --plans

# Documentation:
mkdocs build --strict
```

## Current Quality Notes

- `terraform fmt -check -recursive` currently reports pre-existing formatting drift; see `PROGRESS.md`.
- The shell scripts pass syntax checks as of 2026-09-14.
- `restore-session.sh` currently restores `sample-program`, `infrastructure`, and backend/dev; Cloud SQL and frontend remain manual milestones.
- Documentation may lag recent implementation changes. Verify claims against source and update both when behavior changes.
