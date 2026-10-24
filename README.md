# terraform-concepts

A working notebook for learning Terraform properly — theory, isolated exercises, real GCP
labs, and a five-repo GKE/Helm sandbox that actually applies.

**Docs site:** <https://nitinkc.github.io/terraform-concepts/> ·
**Start here:** [`docs/reference/index.md`](docs/reference/index.md) — a unified 11-part architectural reference combining theory, local basics (`01-basics/`), and GCP implementations (`02-gcp-terraform/`).

## Layout

```
docs/reference/        Unified 11-article architectural reference + cheatsheets.
docs/sandbox/          Multi-repo GKE/Helm/Consul sandbox documentation & runbook.
docs/quiz/             66 scenario-based quiz questions across 6 topics.
01-basics/             8 local Terraform roots in 7 folders. No cloud, no auth, no cost.
02-gcp-terraform/      The same concepts against a real GCP project (VPC, peering, IAP, modules).
acme-sampleapp-.../    The sandbox: 5 interdependent roots, Consul, GKE, Cloud SQL, Helm.
```

The repository is deliberately two layers:

- **`01-basics/` and `02-gcp-terraform/`** are small, isolated demonstrations. One concept
  per directory, safe to break, safe to delete. Every explanation and code snippet is consolidated in
  [`docs/reference/`](docs/reference/index.md).

- **`acme-sampleapp-multirepo`** is the main project. Its five
  independent Terraform roots model organisation-style repository boundaries, state
  ownership, Consul contracts, GKE, Cloud SQL, Helm and Workload Identity. It bills real
  money — read its [RUNBOOK](acme-sampleapp-multirepo/RUNBOOK.md) before
  applying anything, and `./destroy-all.sh` when you pause.

Each sandbox `*/infra/` directory owns its own state file. Don't copy or delete state files
between roots.

## The path

| Area | Where | Costs |
|---|---|---|
| 1 — Reference (Theory + Local + GCP) | [`docs/reference/`](docs/reference/index.md) + `01-basics/` + `02-gcp-terraform/` | nothing / cents |
| 2 — Sandbox | [`docs/sandbox/`](docs/sandbox/index.md) + `acme-sampleapp-.../` | real money |

Check yourself with the [quiz](docs/quiz/index.md) — 66 questions across 6 topics, covering
every architectural reference topic and real debugging incidents.

## Local tooling

Serve the docs:

```bash
pip install -r requirements.txt
mkdocs serve

# or, without touching your environment
uvx --with mkdocs-material mkdocs serve
```

Render a dependency graph from any Terraform root (needs Graphviz):

```bash
terraform graph | dot -Tsvg > graph.svg
```

Kill the Consul dev agent when done: `kill %1` (or find it with `jobs`).
`-dev` mode is in-memory anyway — nothing persists once it's killed.
```shell
kill $(pgrep consul)
```

Clean all tffile

```shell
find . \( -name ".terraform*" -o -name "*tfstate*" -o -name "*.tfplan" \) -exec rm -rf {} +
```
