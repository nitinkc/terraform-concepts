# 12 — Modules

**Assumes:** [Data sources](11-data-sources.md).

A **module** is a directory of `.tf` files treated as a reusable unit: inputs in, resources
created, outputs out. There is nothing special about the directory — every Terraform
config is already a module.

| Term | Meaning |
|---|---|
| **Root module** | the directory you run `terraform` in |
| **Child module** | any directory pulled in with a `module` block |

## Calling one

```hcl
module "backend_sa" {
  source       = "./modules/service_account"

  project_id   = var.project_id
  account_id   = "${local.name_prefix}-web-app"
  display_name = "Backend SA"
}

output "backend_sa_email" {
  value = module.backend_sa.email
}
```

Inside `./modules/service_account/`:

```hcl
# variables.tf — the input schema
variable "project_id"   { type = string }
variable "account_id"   { type = string }
variable "display_name" { type = string }

# main.tf
resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
}

# outputs.tf — the only things the caller can see
output "email"      { value = google_service_account.this.email }
output "account_id" { value = google_service_account.this.account_id }
```

The interface is exactly `variable` blocks in and `output` blocks out. A caller cannot
reach a resource inside a module; if it needs a value, the module must output it. That
restriction is the entire benefit — it's what makes a module refactorable.

Convention inside a child module is to name the primary resource `this`, since it's already
namespaced by the module name.

## State addressing

```bash
terraform state list
# module.backend_sa.google_service_account.this
```

Module-created resources get a `module.<name>.` prefix, which distinguishes them from
root-level resources and nests further for
[`for_each` over modules](09-count-for-each-and-dynamic.md):

```
module.app_sa["dev"].google_service_account.this
```

Consequence: **moving a resource into a module is, to Terraform, a rename** — destroy and
create — unless you `terraform state mv` it or write a `moved` block. That is the single
most expensive mistake available when modularising an existing config.

## Sources and versioning

| `source` | Use |
|---|---|
| `./modules/vpc` | local path — same repo, no versioning, always in lockstep |
| `git::https://…//modules/vpc?ref=v1.4.0` | another repo, pinned to a tag |
| `terraform-google-modules/network/google` + `version = "~> 9.0"` | registry module, semver-constrained |

Local paths are re-read on every `init`; remote sources are *cached* under `.terraform/`,
so changing a `ref` or `version` requires `terraform init -upgrade`. Unpinned remote
modules are the same reproducibility problem as unpinned providers
([§3](03-init-and-version-constraints.md)), with less tooling to protect you — there's no
lock file entry for a git-sourced module.

## Providers are inherited, aliases are not

A child module uses the caller's default provider configuration automatically. An
[aliased provider](02-providers-and-authentication.md) must be passed explicitly:

```hcl
module "east_bucket" {
  source    = "./modules/bucket"
  providers = { google = google.us_east }
}
```

A child module should **not** declare its own `provider {}` block. It may declare
`required_providers` (to state which providers it needs, and their version constraints),
but configuration belongs to the root — otherwise the module can't be reused anywhere else.

## When not to modularise

A module is an abstraction, and abstractions cost more to read than the code they replace.
The honest heuristics:

- **Two callers minimum.** A module with one caller is indirection, not reuse.
- **Don't wrap a single resource.** `module "bucket"` around one `google_storage_bucket`
  adds an interface to maintain and removes access to every attribute you didn't output.
- **Modules are for a *unit of infrastructure*** — a network, a GKE cluster with its node
  pools and service account, a service's full footprint — not for a resource type.
- **Keep conditionality out.** Filter the collection in the caller's `locals` and
  `for_each` the module over the result, so the module never contains a
  [guard](08-expressions-and-conditionals.md).

## Key takeaway

A module is inputs, resources, outputs, and a `module.<name>.` prefix in state. The prefix
is what makes extracting a module out of working code a destroy-and-recreate unless you
move state deliberately.

---

Labs: [Lab 9](../gcp/02-lab-notes.md#lab-9-modules-packaging-reusable-infra),
[Lab 13](../gcp/02-lab-notes.md#lab-13-for_each-over-modules),
[Core GCP root](../gcp/01-core-root.md) ·
Next: [State lifecycle](13-state-lifecycle.md)
