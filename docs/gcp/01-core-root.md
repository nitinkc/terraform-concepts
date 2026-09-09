# Core GCP root

**Code:** [`02-gcp-terraform/01-core-gcp-resources/`](https://github.com/nitinkc/terraform-concepts/tree/main/02-gcp-terraform/01-core-gcp-resources)

One Terraform root, split across files by concern, exercising most of what
[Stage 2](../basics/index.md) taught locally — but against a real Google Cloud project.

This is the first code in the learning path laid out the way a real root is laid out: not
one `main.tf` with everything in it, but a file per concern that Terraform concatenates at
runtime. Terraform itself does not care about file names; you and everyone after you do.

## What's in here

| File | Concept | Theory |
|---|---|---|
| `main.tf` | `required_version`, `required_providers` (google + random), and the `provider "google"` config block | [§2](../theory/02-providers-and-authentication.md), [§3](../theory/03-init-and-version-constraints.md) |
| `backend.tf` | Remote state in a GCS bucket, as a *partial* config — `bucket`/`prefix` come from `-backend-config` | [§14](../theory/14-backends-and-state-security.md) |
| `variables.tf` | Typed inputs; note `set(string)` vs the commented-out `list(string)` | [§7](../theory/07-variables-and-locals.md) |
| `terraform.tfvars` | Values, overriding the defaults in `variables.tf` | [§7](../theory/07-variables-and-locals.md) |
| `locals.tf` | Derived values — `name_prefix`, `common_labels`, and a list driving a `dynamic` block | [§7](../theory/07-variables-and-locals.md) |
| `data.tf` | `google_project` and `google_compute_network` — reading things this root doesn't own | [§11](../theory/11-data-sources.md) |
| `network.tf` | A VPC and subnet, with an implicit dependency between them | [§6](../theory/06-dependencies-and-the-graph.md) |
| `compute.tf` | A `module` call into `modules/gcp-vm/` | [§12](../theory/12-modules.md) |
| `resources.tf` | `for_each` over service accounts, an IAM binding, and a `dynamic "lifecycle_rule"` block | — |
| `outputs.tf` | Structured output (a map, not just a string) | [§10](../theory/10-outputs.md) |
| `modules/gcp-vm/` | A minimal module: `main.tf` / `variables.tf` / `outputs.tf` | — |

## Before you run it

**Set your own project.** Two places name `my-devops-journey-502420` — the `default` in
`variables.tf` and the value in `terraform.tfvars`. **The tfvars value wins; the default is
never used.** That precedence rule is [Lab 15](02-lab-notes.md#lab-15-terraformtfvars-variable-precedence),
it's covered in [Stage 2](../basics/02-variables.md#precedence-the-gotcha-that-costs-real-time),
and it cost real debugging time in [Session 2](../sessions/session-02.md). Changing only
the default and wondering why nothing happened is the classic version of this mistake.

**Create the state bucket first** — see [the stage prerequisites](index.md#create-the-state-bucket-first).
`backend.tf` is a *partial* configuration: it names the `gcs` backend but supplies neither
`bucket` nor `prefix`, so both come from `-backend-config` at init time. That is deliberate
— a bucket name hardcoded in a public repo is a name someone else already owns, and the
prefix has to be yours so two roots never write state to the same path.

Worth knowing the failure mode before you hit it: forgetting `-backend-config` does **not**
produce "bucket not set". Terraform accepts the empty value and asks Cloud Storage about it
anyway, so you get `Failed to get existing workspaces: storage: bucket doesn't exist … 404`
— the same error you'd get from a typo in a real bucket name. If you see that on your first
`init`, check whether you passed the flag at all before you go looking at IAM.

## Run

```bash
terraform init \
  -backend-config="bucket=YOUR-UNIQUE-BUCKET-NAME-tfstate" \
  -backend-config="prefix=core-gcp-resources/state"

terraform plan  -var="project_id=YOUR_PROJECT_ID"
terraform apply -var="project_id=YOUR_PROJECT_ID"

terraform output project_number
terraform output default_network_self_link
terraform output server_internal_ip

terraform destroy -var="project_id=YOUR_PROJECT_ID"     # the VM bills per second
```

Regenerate the dependency graph (needs Graphviz):

```bash
terraform graph | dot -Tsvg > graph.svg
```

[`graph.svg`](https://github.com/nitinkc/terraform-concepts/blob/main/02-gcp-terraform/01-core-gcp-resources/graph.svg)
is checked in — worth opening before your first `apply` to see how much ordering Terraform
derived that nobody declared.

## Things worth noticing

**`count` and `for_each` side by side.** `resources.tf` keeps the `count` version commented
out directly above the `for_each` version, and `variables.tf` keeps both `list(string)` and
`set(string)` type declarations. Don't delete either — switch between them, run
`terraform state list`, and compare the addresses:

```
google_service_account.env_sa[0]        # count — positional
google_service_account.env_sa["dev"]    # for_each — keyed
```

Then remove the *first* element from the list and re-plan. With `count`, everything after
it shifts index and gets destroyed and recreated. With `for_each`, only the removed key is
touched. That single experiment is the entire argument for `for_each`
([Stage 2](../basics/07-count-and-for-each.md) has the free version), and it's the same
mechanic that shows up in the sandbox's `module "gke"`.

**`uniform_bucket_level_access = true` is set explicitly**, with a comment explaining why:
the org policy forbids legacy ACLs, and the provider defaults this to `false`. A good
example of provider defaults not matching your environment's requirements — you find these
by failing an apply, not by reading docs. The failure mode is
`Error 412: constraints/storage.uniformBucketLevelAccess`, and the debugging story is in
[Lab 8](02-lab-notes.md#lab-8-locals-computedderived-values).

**The `dynamic "lifecycle_rule"` block** in `resources.tf` generates three storage-class
transitions from `local.lifecycle_rules`. Add a fourth entry to the local and re-plan: one
line of data, no new resource block. That's the point of `dynamic`, and this is the only
`dynamic` block in this root — the other one in the repository is
`dynamic "rule"` in the sandbox's `backend/infra/rbac.tf`.

**Both `required_providers` and the `provider` block live in `main.tf`.** Every root in the
[sandbox](../sandbox/index.md) splits these into `versions.tf` and `providers.tf` instead —
see [Theory §17](../theory/17-project-structure.md). Left as-is
here so the contrast is visible; the sandbox layout is the one to copy for anything real.

**Outputs are declared in three different files.** `outputs.tf` has `service_account`,
`data.tf` has `project_number` and `default_network_self_link`, and `compute.tf` has
`server_internal_ip`. They all work — Terraform concatenates every `.tf` in the directory —
but "where is this output defined" becomes a `grep` instead of a glance. Another deliberate
inconsistency worth noticing rather than inheriting.

**The `random` provider is declared but never used.** `main.tf` lists `hashicorp/random` in
`required_providers`, and no `random_*` resource exists anywhere in the root. It costs a
plugin download on every `init` and misleads the next reader into thinking something
generates a random value. This is the same class of smell as an unused `variable` — see
[Stage 2](../basics/11-provider-versions.md#a-provider-block-isnt-always-needed) for why
`required_providers` and `provider {}` are separate decisions.

## Where each file shows up in the lab notes

The [lab notes](02-lab-notes.md) isolate these concepts one at a time, against the acme
codebase. Read a row in either direction.

| This root | Isolated in |
|---|---|
| `backend.tf` | [Lab 1](02-lab-notes.md#lab-1-local-state), [Lab 2](02-lab-notes.md#lab-2-remote-state-gcs-backend) |
| `resources.tf` — IAM member | [Lab 3](02-lab-notes.md#lab-3-implicit-dependency-iam-binding) |
| `resources.tf` — `env_sa` (commented `count`) | [Lab 4](02-lab-notes.md#lab-4-count-indexed-multiple-resources) |
| `resources.tf` — `env_sa` (`for_each`) | [Lab 5](02-lab-notes.md#lab-5-for_each-keyed-multiple-resources) |
| — | [Lab 6](02-lab-notes.md#lab-6-state-surgery-mv-rm-import), [Lab 11](02-lab-notes.md#lab-11-import-drift-detection) |
| `data.tf` | [Lab 7](02-lab-notes.md#lab-7-data-sources) |
| `locals.tf` | [Lab 8](02-lab-notes.md#lab-8-locals-computedderived-values) |
| `compute.tf`, `modules/gcp-vm/` | [Lab 9](02-lab-notes.md#lab-9-modules-packaging-reusable-infra), [Lab 13](02-lab-notes.md#lab-13-for_each-over-modules) |
| — | [Lab 10](02-lab-notes.md#lab-10-workspaces-multi-environment-state-isolation) |
| `resources.tf` — `lifecycle_demo` | [Lab 12](02-lab-notes.md#lab-12-dynamic-blocks) |
| `main.tf` — provider block | [Lab 14](02-lab-notes.md#lab-14-provider-aliasing-multi-region-multi-project) |
| `terraform.tfvars`, `variables.tf` | [Lab 15](02-lab-notes.md#lab-15-terraformtfvars-variable-precedence) |
| — | [Lab 16](02-lab-notes.md#lab-16-lifecycle-meta-arguments), [Lab 17](02-lab-notes.md#lab-17-provisioners-null_resource-brief) |

Rows with a dash have no counterpart in this root — workspaces, state surgery and
lifecycle guards are only exercised in the lab notes.

---

Next: [Lab notes 1–18](02-lab-notes.md)
