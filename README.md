# terraform-concepts

A working notebook for learning Terraform properly — theory, isolated exercises, real GCP
labs, and a five-repo GKE/Helm sandbox that actually applies.

**Docs site:** <https://nitinkc.github.io/terraform-concepts/> ·
**Start here:** [`docs/theory/concept-index.md`](docs/theory/concept-index.md) maps every concept to the
theory that defines it, the lab that isolates it, the code that uses it for real, and the
quiz that tests it.

## Layout

```
docs/                  The site. Theory, labs, quiz, session notes.
01-basics/             7 local Terraform roots. No cloud, no auth, no cost.
02-gcp-terraform/      The same concepts against a real GCP project.
acme-sampleapp-.../    The sandbox: 5 interdependent roots, Consul, GKE, Cloud SQL, Helm.
```

The repository is deliberately two layers:

- **`01-basics/` and `02-gcp-terraform/`** are small, isolated demonstrations. One concept
  per directory, safe to break, safe to delete. These directories contain `.tf` files
  only — every explanation lives in the docs, so there is one place to read and one place
  to run. Start at [`docs/basics/`](docs/basics/index.md).
- **`acme-sampleapp-multirepo-sandbox-elaborate/`** is the main project. Its five
  independent Terraform roots model organisation-style repository boundaries, state
  ownership, Consul contracts, GKE, Cloud SQL, Helm and Workload Identity. It bills real
  money — read its [RUNBOOK](acme-sampleapp-multirepo-sandbox-elaborate/RUNBOOK.md) before
  applying anything, and `./destroy-all.sh` when you pause.

Each sandbox `*/infra/` directory owns its own state file. Don't copy or delete state files
between roots.

## The path

| Stage | Where | Costs |
|---|---|---|
| 1 — Theory | [`docs/theory/`](docs/theory/index.md) — 19 pages in dependency order | nothing |
| 2 — Basics | [`docs/basics/`](docs/basics/index.md) + [`01-basics/`](01-basics/) | nothing |
| 3 — GCP | [`docs/gcp/`](docs/gcp/index.md) + [`02-gcp-terraform/`](02-gcp-terraform/) | cents |
| 4 — Sandbox | [`docs/sandbox/`](docs/sandbox/index.md) + `acme-sampleapp-.../` | real money |

Check yourself with the [quiz](docs/quiz/index.md) — 33 questions across 6 topics, all
drawn from things that actually happened. The [session log](docs/sessions/index.md) is the
narrative version.

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
