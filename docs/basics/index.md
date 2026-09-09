# Stage 2 — Basics (local, no cloud)

Thirteen topics that prove every core Terraform mechanic without touching a cloud API.
Nothing here authenticates, costs money, or can be broken in a way that matters. The
`local`, `random`, `null` and `archive` providers write files to `/tmp` — but the
lifecycle, the state file, the dependency graph and the plan/apply loop are the real
thing, identical to what runs against GCP in [Stage 3](../gcp/index.md).

The code lives in [`01-basics/`](https://github.com/nitinkc/terraform-concepts/tree/main/01-basics),
seven self-contained Terraform roots. This section is the only prose — the folders hold
`.tf` files and nothing else.

## Prerequisites

```bash
terraform version      # anything 1.x
```

That's it. No `gcloud`, no credentials, no billing account. Graphviz is optional and only
needed for [`terraform graph`](04-references-and-dependencies.md#seeing-the-graph):

```bash
brew install graphviz
```

## The sequence

Ordered by difficulty, not by folder number. Six topics have no folder yet — the code is
in the page, ready to paste into a scratch root.

| # | Topic | Folder | Writes |
|---|---|---|---|
| 1 | [Resources and state](01-resources-and-state.md) | `1-create-local-file/` | `/tmp/hello.txt` |
| 2 | [Variables](02-variables.md) | `2-variable-use/` | `/tmp/helloFruits.txt` |
| 3 | [Locals](03-locals.md) | — | `/tmp/tf-practice/greeting-*.txt` |
| 4 | [References and dependencies](04-references-and-dependencies.md) | `3-resource-attribute-reference/`, `4-dependencies/` | `/tmp/hello_resourceAttribute.txt`, `/tmp/hello_{im,ex}plicit_dependencies.txt` |
| 5 | [Outputs](05-outputs.md) | `4-dependencies/explicit/` | nothing |
| 6 | [Data sources](06-data-sources.md) | `6-data-sources/` | `/tmp/hello.txt` |
| 7 | [count and for_each](07-count-and-for-each.md) | — | `/tmp/pet-*.txt` |
| 8 | [Conditionals](08-conditionals.md) | — | `/tmp/backup.txt` |
| 9 | [Lifecycle](09-lifecycle.md) | `5-lifecycle/` | `/tmp/hello.txt` |
| 10 | [Validation and sensitive values](10-validation-and-sensitive-values.md) | — | `/tmp/app-config.txt` |
| 11 | [Provider versions](11-provider-versions.md) | `7-version-constraints/` | `./hello.txt` |
| 12 | [State surgery](12-state-surgery.md) | — | nothing new |
| 13 | [Provisioners and archive_file](13-provisioners-and-archive.md) | — | `/tmp/greeting-*.txt`, `/tmp/tf-practice-bundle.zip` |

Folder numbers and topic numbers deliberately don't line up. The folders were numbered in
the order they were written; the topics are numbered in the order that makes them easiest
to learn.

## Running any of them

```bash
cd 01-basics/1-create-local-file
terraform init
terraform plan
terraform apply
terraform state list          # what Terraform now thinks it owns
terraform destroy
```

Each folder is an independent root with its own state. `terraform destroy` between topics
is optional here — nothing costs money and nothing needs cleanup approval — but several
folders write to the same `/tmp/hello.txt`, so destroying as you go avoids confusion about
which root owns the file.

## Deliberate defects

Three folders contain bugs on purpose. Fixing them teaches more than reading a working
example, so don't "clean them up" without reading the relevant page first.

| Folder | Defect | Page |
|---|---|---|
| `5-lifecycle/` | `ignore_changes = [tags]` — `local_file` has no `tags` attribute, so this errors | [Lifecycle](09-lifecycle.md) |
| `7-version-constraints/` | Writes `hello.txt` to the current directory while the comment says `/tmp` | [Provider versions](11-provider-versions.md) |
| `3-…` vs `4-dependencies/implicit/` | Byte-identical `main.tf`, which looks like duplication and isn't | [References and dependencies](04-references-and-dependencies.md) |

## Not yet implemented

Six topics are documented here but have no folder under `01-basics/`. The code on each
page is complete and runnable — paste it into an empty directory and `terraform init`.

| Topic | Why it's worth building |
|---|---|
| [Locals](03-locals.md) | — |
| [count and for_each](07-count-and-for-each.md) | — |
| [Conditionals](08-conditionals.md) | — |
| [Validation and sensitive values](10-validation-and-sensitive-values.md) | — |
| [State surgery](12-state-surgery.md) | **Highest value.** State surgery is far cheaper to practise on a `local_file` than on a GCP resource, and it's the same muscle needed for [GCP Lab 6](../gcp/02-lab-notes.md#lab-6-state-surgery-mv-rm-import) and [Lab 11](../gcp/02-lab-notes.md#lab-11-import-drift-detection). |
| [Provisioners and archive_file](13-provisioners-and-archive.md) | — |

## Conventions

- One directory per concept, numbered in the order they were written.
- `main.tf` for resources, `variables.tf` for inputs — the same layout as
  [`02-gcp-terraform/`](../gcp/01-core-root.md) and every root in the
  [sandbox](../sandbox/index.md), so moving between them costs nothing.
- `.terraform/`, `terraform.tfstate` and lock files are gitignored. Only the HCL is
  committed.

Start with **[Resources and state](01-resources-and-state.md)**.
