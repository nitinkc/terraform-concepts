# acme-sampleapp — Terraform + Helm multi-repo learning sandbox

The actual project layout: each application owns its own `infra/`
(and `charts/` where applicable), and repos coordinate through Consul-published
outputs rather than `terraform_remote_state`. 

Nothing here will actually `terraform apply` anywhere real — the Consul paths
and GCS backends don't exist. This is for reading, tracing the dependency
graph, and rewriting pieces by hand.

`cloudsql`'s `frontend`'s app source (Angular/FastAPI) and `cloudsql`'s SQL
migrations are intentionally **not** reconstructed — out of scope for a
Terraform-focused sandbox.

## Repo layout

```
backend/
  infra/          Terraform: namespace, GSA, Cloud SQL IAM + the shell_script grant
                  bridge, dynamic RBAC, the helm_release that installs the chart below
  charts/acme-sampleapp-backend/   FastAPI + Cloud SQL Auth Proxy sidecar

frontend/
  infra/          Terraform: namespace, GSA, static IP + DNS (vip.tf), the
                  helm_release that installs the chart below
  charts/acme-sampleapp-frontend/  Angular build served by nginx, GCE ingress

cloudsql/
  infra/          Terraform: the actual Cloud SQL instance, IAM-auth enabled,
                  plus the grant/revoke Cloud Functions backend/infra calls into

infrastructure/
  infra/          Terraform: shared SSO secret (Secret Manager), published to
                  every other repo via Consul
```

## Why 4 separate Terraform repos instead of one

This is the distinctive architectural choice worth understanding on its own —
it's a distributed-systems pattern applied to infrastructure code, not just an
organizational preference. Each repo:

- Has **its own lifecycle** — the database shouldn't be destroyed/recreated
  just because the backend redeploys, and the frontend shouldn't need a plan
  run every time a DB migration ships.
- Has **its own state file** (`backend "gcs" {}` per repo, no shared backend
  config) — blast radius of a bad `apply` is contained to one repo.
- **Publishes what other repos need, and nothing else**, through Consul rather
  than `terraform_remote_state`. `terraform_remote_state` would create a hard
  coupling to another repo's *entire* state file (including things it never
  meant to expose); a Consul KV write is a deliberate, versioned, minimal
  publish/subscribe contract instead — closer to a service publishing an API
  contract than one service reading another's database directly.

## Dependency graph

```
        sample-program (platform repo, not part of this sandbox)
                    │  publishes: GKE cluster, VPC, DNS zone
                    ▼
        ┌───────────────────────┐
        │   infrastructure/      │  publishes: sso_secret_id, sso_client_id,
        │                        │             project_id  (per env: dev/qa/prod)
        └────────────┬───────────┘
                      │
        ┌─────────────┼─────────────┐
        ▼                            ▼
┌──────────────┐            ┌──────────────┐
│  cloudsql/    │            │              │
│               │            │              │
│  publishes:   │            │              │
│  connection   │            │              │
│  info, grant/ │            │              │
│  revoke URLs  │            │              │
└───────┬───────┘            │              │
        │                    │              │
        ▼                    ▼              │
┌───────────────────────────────┐           │
│           backend/             │◄──────────┘
│                                │   reads: sso_secret_id (grants itself
│  publishes: backend_service_url│   secretAccessor), cloudsql outputs
│  service_account.email         │
└───────────────┬────────────────┘
                 │
                 ▼
        ┌─────────────────┐
        │   frontend/       │  reads: backend_service_url, sso_client_id
        │                   │  (never touches sso_secret_id/client_secret)
        └───────────────────┘
```

`infrastructure` also reads `backend`'s published service-account email
(`../acme-sampleapp-multirepo-sandbox/infrastructure/infra/iam.tf`) — the *grant* runs in `infrastructure` (it
owns the secret) even though the *dependency* on knowing who to grant flows
the other way. This is worth sitting with: **"who owns the resource" and
"who initiates the Terraform read" aren't always the same repo.**

## Consul key map (the actual contract between repos)

| Path | Written by | Read by |
|---|---|---|
| `.../sample-program/default` | *(platform repo, out of scope)* | all 4 repos |
| `.../infrastructure/{dev,qa,default}` | `../acme-sampleapp-multirepo-sandbox/infrastructure/infra` | `backend`, `frontend` |
| `.../cloudsql/{dev,qa,default}` | `../acme-sampleapp-multirepo-sandbox/cloudsql/infra` | `backend` |
| `.../backend/{workspace}` | `../acme-sampleapp-multirepo-sandbox/backend/infra` | `frontend`, `infrastructure` |

Every one of these paths is decoded with `jsondecode(...)` on the reading
side and encoded with `jsonencode(...)`/`consul_keys` on the writing side —
if you ever change a field name on one side, grep the whole sandbox for it
before assuming the change is safe. That's the tradeoff of a JSON-over-KV
contract instead of typed Terraform module outputs: nothing catches a typo
at plan time.

## What to trace first

1. `../acme-sampleapp-multirepo-sandbox/infrastructure/infra/main.tf` and `secrets.tf` — the simplest repo, good
   warm-up for the `for_each`-over-environments pattern (note: this repo does
   **not** use `terraform.workspace` per environment the way the other three
   do — it runs a single workspace and fans out with `for_each` instead. Ask
   yourself why that choice might make sense here specifically.)
2. `../acme-sampleapp-multirepo-sandbox/cloudsql/infra` — a self-contained, single-purpose repo. Good for seeing
   a full `main.tf` → `iam.tf` → `outputs.tf` flow without the added
   complexity backend has.
3. `../acme-sampleapp-multirepo-sandbox/backend/infra/main.tf` locals, then `cloudsql.tf`, then the `depends_on`
   block at the bottom of `main.tf` — same as before, this is still the most
   architecturally dense file in the sandbox.
4. `../acme-sampleapp-multirepo-sandbox/frontend/infra/vip.tf` + `iam.tf` — contrast against backend's `iam.tf`:
   notice everything backend needs (SQL roles, `shell_script` bridge,
   `sso_secret_id` access) that frontend deliberately does **not** need, and
   why (no database, and `sso_client_id` is non-sensitive so it skips Secret
   Manager IAM entirely).
