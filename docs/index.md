# Terraform Learning

A working notebook, not a tutorial. Everything here was written while learning Terraform
against a real GCP project — the labs record what was actually run, the quiz questions come
out of things that actually broke, and the session notes record the wrong answers as well
as the right ones.

If you are looking for a specific concept rather than a place to start, go straight to the
**[concept index](theory/concept-index.md)** — it maps every concept to its theory page, its
local lab, its GCP lab, the sandbox file that uses it for real, and the quiz that tests it.

## The path

Four stages, ordered by *what it costs you to be wrong* — which turns out to be the same as
ordering by complexity.

| | Stage | What it is | Needs | Costs |
|---|---|---|---|---|
| 1 | **[Theory](theory/index.md)** | 19 pages of definitions and mechanics, in dependency order — providers, state, expressions, modules, backends, the execution model | nothing | nothing |
| 2 | **[Basics](basics/index.md)** | 13 topics using `local`/`random`/`null`/`archive`. Real Terraform lifecycle, files on disk instead of cloud resources | Terraform | nothing |
| 3 | **[GCP](gcp/index.md)** | A full Terraform root against a real project, plus 18 lab notes — remote state, modules, workspaces, import, drift | a GCP project | cents |
| 4 | **[Sandbox](sandbox/index.md)** | Five interdependent Terraform roots, a Consul contract, GKE, Cloud SQL, Helm, Workload Identity | GCP + patience | real money |

Test yourself at any point with the **[quiz](quiz/index.md)** (33 questions across 6
topics), and read the **[session log](sessions/index.md)** for the narrative version —
what was attempted, what failed, and why.

## Every topic, in order

### Stage 1 — Theory · nothing to install

Read in order; each page assumes only the one before it.

| # | Page | # | Page |
|---|---|---|---|
| 1 | [What Terraform is](theory/01-what-terraform-is.md) | 11 | [Data sources](theory/11-data-sources.md) |
| 2 | [Providers and authentication](theory/02-providers-and-authentication.md) | 12 | [Modules](theory/12-modules.md) |
| 3 | [`init` and version constraints](theory/03-init-and-version-constraints.md) | 13 | [State lifecycle](theory/13-state-lifecycle.md) |
| 4 | [Resources and state](theory/04-resources-and-state.md) | 14 | [Backends and state security](theory/14-backends-and-state-security.md) |
| 5 | [Resource identity and change](theory/05-resource-identity-and-change.md) | 15 | [Cross-config composition](theory/15-cross-config-composition.md) |
| 6 | [Dependencies and the graph](theory/06-dependencies-and-the-graph.md) | 16 | [GitOps and CI/CD](theory/16-gitops-and-cicd.md) |
| 7 | [Variables and locals](theory/07-variables-and-locals.md) | 17 | [Project structure](theory/17-project-structure.md) |
| 8 | [Expressions and conditionals](theory/08-expressions-and-conditionals.md) | 18 | [CLI reference](theory/18-cli-reference.md) |
| 9 | [`count`, `for_each`, `dynamic`](theory/09-count-for-each-and-dynamic.md) | 19 | [Glossary](theory/19-glossary.md) |
| 10 | [Outputs](theory/10-outputs.md) | | |

### Stage 2 — Basics · no cloud, no cost

| # | Topic | Code |
|---|---|---|
| 1 | [Resources and state](basics/01-resources-and-state.md) | `01-basics/1-create-local-file/` |
| 2 | [Variables](basics/02-variables.md) | `01-basics/2-variable-use/` |
| 3 | [Locals](basics/03-locals.md) | — |
| 4 | [References and dependencies](basics/04-references-and-dependencies.md) | `01-basics/3-…`, `01-basics/4-dependencies/` |
| 5 | [Outputs](basics/05-outputs.md) | `01-basics/4-dependencies/explicit/` |
| 6 | [Data sources](basics/06-data-sources.md) | `01-basics/6-data-sources/` |
| 7 | [count and for_each](basics/07-count-and-for-each.md) | — |
| 8 | [Conditionals](basics/08-conditionals.md) | — |
| 9 | [Lifecycle](basics/09-lifecycle.md) | `01-basics/5-lifecycle/` |
| 10 | [Validation and sensitive values](basics/10-validation-and-sensitive-values.md) | — |
| 11 | [Provider versions](basics/11-provider-versions.md) | `01-basics/7-version-constraints/` |
| 12 | [State surgery](basics/12-state-surgery.md) | — |
| 13 | [Provisioners and archive_file](basics/13-provisioners-and-archive.md) | — |

### Stage 3 — GCP · cents

| Page | Code |
|---|---|
| [Prerequisites and cost](gcp/index.md) | — |
| [Core GCP root](gcp/01-core-root.md) | `02-gcp-terraform/01-core-gcp-resources/` |
| [Lab notes 1–18](gcp/02-lab-notes.md) | `acme-sampleapp-…/` |

### Stage 4 — Sandbox · real money

| Page | Code |
|---|---|
| [The acme-sampleapp sandbox](sandbox/index.md) | `acme-sampleapp-…/` |
| [Runbook](sandbox/runbook.md) | apply order, Consul dev agent, teardown |

## Code in this repository

```
01-basics/             7 local Terraform roots. No cloud, no auth, no cost.
02-gcp-terraform/      The same concepts against a real GCP project.
acme-sampleapp-.../    5 interdependent roots, Consul, GKE, Cloud SQL, Helm.
```

The code directories contain `.tf` files only — every explanation lives here in the docs,
linked from the tables above, so there is one place to read and one place to run.

## Running these docs locally

```bash
pip install -r requirements.txt
mkdocs serve
```

Or without installing anything into your environment:

```bash
uvx --with mkdocs-material mkdocs serve
```

Some pages embed diagrams generated from real Terraform state. To regenerate one
(needs Graphviz):

```bash
terraform graph | dot -Tsvg > graph.svg
```
