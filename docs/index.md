# Terraform Learning & Architect's Reference

A working notebook and architectural reference built against real local roots, a GCP project, and a five-repo GKE/Helm/Consul sandbox.

Start at the **[Architect's Reference](reference/index.md)** — 11 sequential, zero-noise articles combining **core theory**, **local cheatsheets (`01-basics/`)**, and **GCP production implementations (`02-gcp-terraform/` & Sandbox)** with a focus on interview-worthy mechanics and architectural trade-offs.

---

## Navigation Overview

| Section | What It Contains | Code Directories |
|---|---|---|
| **[Architect's Reference](reference/index.md)** | 11 sequential articles merging Theory + Local Basics + GCP labs + Cheatsheet | `01-basics/`, `02-gcp-terraform/` |
| **[GCP Visual Labs](gcp-labs/index.md)** | 4 GCP networking & core-resource labs with sliced SVG diagrams & interactive HTML inspectors | `02-gcp-terraform/` |
| **[Acme Sandbox](sandbox/index.md)** | Five interdependent Terraform roots, Consul contracts, GKE, Cloud SQL, Helm, Workload Identity | `../acme-sampleapp-multirepo` |
| **[Quiz](quiz/index.md)** | 66 scenario questions across 6 topics, covering all reference articles and real debugging incidents | — |

---

## Sequential Reference Articles

| # | Article | Key Topics |
|---|---|---|
| 1 | [Execution Model, Providers & Auth](reference/01-execution-model-and-providers.md) | 3-way diff, Core vs Provider, `required_providers` vs `provider {}`, ADC precedence, lock files, aliasing |
| 2 | [Resources, State Mechanics & Backends](reference/02-resources-state-and-backends.md) | State ledger purpose, non-atomic apply, clobber vs 409, GCS backend chicken-and-egg, `plan` read-access security |
| 3 | [Resource Identity, Change & Lifecycle](reference/03-identity-lifecycle-and-change.md) | Address identity, `moved` blocks, in-place vs Force-New, `prevent_destroy`, `ignore_changes`, `create_before_destroy` |
| 4 | [Dependencies & the Execution Graph](reference/04-dependencies-and-graph.md) | Implicit reference edges, when `depends_on` is required vs redundant, reverse destroy order, plan-time unknowns |
| 5 | [Variables, Precedence, Locals & Sensitive Data](reference/05-variables-locals-and-security.md) | Exact variable precedence order, type constraints, `validation`, why `sensitive = true` is not encryption, volatile functions |
| 6 | [Expressions, Conditionals & Guard Propagation](reference/06-expressions-conditionals-and-guards.md) | Ternaries, `for` comprehensions, `try`/`one`/`coalesce`, `count = 0` empty-list trap, downstream **guard propagation** |
| 7 | [Repetition: `count`, `for_each` & `dynamic`](reference/07-repetition-count-for-each-dynamic.md) | Index-shift destruction vs keyed stability, `for_each` over modules, `dynamic` nested blocks, plan-time key rule |
| 8 | [Data Sources, Outputs & Module Design](reference/08-data-sources-outputs-and-modules.md) | Live `data` reads vs `resource`, `google_client_config` token expiry, `-raw` vs `-json`, module boundaries, `archive_file` vs `local-exec` |
| 9 | [State Surgery, Drift, Import & Workspaces](reference/09-state-surgery-drift-and-workspaces.md) | `state mv`/`rm`/`import`, import-vs-recreate decision framework, import diff trap, workspace isolation caveats |
| 10 | [Production Architecture: Multi-Repo, GKE, Networking & CI/CD](reference/10-architecture-multirepo-gke-and-cicd.md) | Root blast radius, Consul KV vs `terraform_remote_state`, VPC/IAP/Peering, GKE transient node pool & Workload Identity, GitOps PR security |
| 11 | [Master HCL, CLI & Glossary Cheatsheet](reference/11-cli-and-hcl-cheatsheet.md) | Annotated all-in-one HCL template, complete CLI lookup table, and 1-line architectural glossary |

---

## Running Docs & Graphs Locally

```bash
pip install -r requirements.txt
mkdocs serve

# Or without modifying your local Python environment:
uvx --with mkdocs-material mkdocs serve

# Render a Terraform dependency graph (requires Graphviz):
terraform graph | dot -Tsvg > graph.svg
```
