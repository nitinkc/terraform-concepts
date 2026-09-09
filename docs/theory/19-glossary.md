# 19 — Glossary

Fast lookup. Each term links to the page that defines it properly.

| Term | Definition | Page |
|:---|:---|:---|
| **ADC** (Application Default Credentials) | ambient Google credentials read from `~/.config/gcloud/application_default_credentials.json` | [§2](02-providers-and-authentication.md) |
| **Backend** | where state is stored — local disk, GCS, S3, Terraform Cloud | [§14](14-backends-and-state-security.md) |
| **Child module** | a directory pulled in with a `module` block | [§12](12-modules.md) |
| **Constraint** | the acceptable version *range* for a provider, e.g. `~> 5.0` | [§3](03-init-and-version-constraints.md) |
| **Data source** | a block Terraform only reads, never manages | [§11](11-data-sources.md) |
| **Declarative** | describing the desired end state rather than the steps | [§1](01-what-terraform-is.md) |
| **Drift** | divergence between state/code and the real, live resource | [§13](13-state-lifecycle.md) |
| **`dynamic` block** | generates repeated *nested blocks* inside one resource | [§9](09-count-for-each-and-dynamic.md) |
| **Force replacement / "Force New"** | a change requiring destroy + recreate because the field can't be updated in place | [§5](05-resource-identity-and-change.md) |
| **`for` expression** | transforms one collection into another; does not create resources | [§8](08-expressions-and-conditionals.md) |
| **`for_each`** | creates one instance per key of a set/map; keyed addressing | [§9](09-count-for-each-and-dynamic.md) |
| **GitOps** | running IaC changes through a Git PR + CI/CD pipeline instead of local execution | [§16](16-gitops-and-cicd.md) |
| **Guard propagation** | every consumer of a conditionally-created resource having to re-check for emptiness | [§8](08-expressions-and-conditionals.md) |
| **HCL** | HashiCorp Configuration Language; the `.tf` file syntax | [§1](01-what-terraform-is.md) |
| **Implicit dependency** | a graph edge created simply by referencing another resource's attribute | [§6](06-dependencies-and-the-graph.md) |
| **`import`** | binds an existing real resource into state under a given address | [§13](13-state-lifecycle.md) |
| **`lifecycle`** | meta-argument overriding default create/update/destroy behaviour | [§5](05-resource-identity-and-change.md) |
| **Local** (`locals`) | an internally computed value, never settable from outside | [§7](07-variables-and-locals.md) |
| **Lock file** (`.terraform.lock.hcl`) | records the exact provider versions/checksums chosen; normally committed to git, though this repo is a deliberate exception | [§3](03-init-and-version-constraints.md) |
| **Meta-argument** | an argument interpreted by Terraform core rather than the provider (`count`, `for_each`, `provider`, `depends_on`, `lifecycle`) | [§9](09-count-for-each-and-dynamic.md) |
| **Module** | a directory of `.tf` files used as a unit: inputs in, outputs out | [§12](12-modules.md) |
| **`moved` block** | a committed, reviewable declaration that a resource changed address | [§5](05-resource-identity-and-change.md) |
| **Output** | a value a config exposes to humans, callers, or other configs | [§10](10-outputs.md) |
| **Provider** | plugin translating HCL into a specific API's calls (GCP, AWS, …) | [§2](02-providers-and-authentication.md) |
| **Provider alias** | a second configuration of the same provider, routed to explicitly | [§2](02-providers-and-authentication.md) |
| **Refresh** | the live-API query step before diffing, on every `plan`/`apply` | [§13](13-state-lifecycle.md) |
| **Resource** | a block Terraform creates, owns and destroys | [§4](04-resources-and-state.md) |
| **Resource address** | `type.local_name[key]` — the identity Terraform uses in state | [§5](05-resource-identity-and-change.md) |
| **Root module** | the directory you run `terraform` in | [§12](12-modules.md) |
| **Secret masking** | CI/CD replacing known secret values with `***` in logs; defeated by transforming the value first | [§16](16-gitops-and-cicd.md) |
| **`sensitive`** | display masking for CLI output — **not** encryption | [§14](14-backends-and-state-security.md) |
| **State file** | JSON ledger mapping HCL resource addresses to real cloud resource IDs | [§4](04-resources-and-state.md) |
| **State locking** | backend-level mutex preventing two simultaneous applies | [§14](14-backends-and-state-security.md) |
| **`terraform_remote_state`** | a data source that reads another config's state outputs from its backend | [§15](15-cross-config-composition.md) |
| **Variable** | an external input to a config, like a function argument | [§7](07-variables-and-locals.md) |
| **Workspace** | a named, isolated state file within the same config | [§13](13-state-lifecycle.md) |

---

Back to the [theory index](index.md) or the [concept index](concept-index.md).
