# Terraform Learning — Lab  (acme-sampleapp)


## Lab 1 — Local State

**Concept:** Terraform maintains a state file (`terraform.tfstate`) mapping your config's
resource addresses to real GCP resource IDs. Without it, Terraform has no memory of what it
owns — it can't tell "already exists, managed by me" from "already exists, not mine."

**Code (already had):**
```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

resource "google_service_account" "gsa" {
  account_id   = "acme-web-app"
  display_name = "My Test App"
}
```

**Commands run:**
```bash
terraform init
terraform plan
terraform apply
terraform state list
terraform state show google_service_account.gsa
```

**Verified:** SA `acme-web-app` visible in IAM & Admin → Service Accounts.

**Key takeaway:** If state is deleted but the real resource still exists, Terraform does
**not** search GCP to reconcile — it just tries to create again, and the GCP API rejects it
with "already exists." Adoption is always explicit (`import`), never automatic.

---

## Lab 2 — Remote State (GCS Backend)

**Concept:** Local state is a single point of failure and has no locking — bad for teams.
Remote state moves the ledger to a GCS bucket, with locking and (if enabled) versioning.

**Setup:**
```bash
gsutil mb -l us-central1 gs://YOUR-UNIQUE-BUCKET-NAME-tfstate
```

**Code added to `terraform {}` block:**
```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
  backend "gcs" {
    bucket = "YOUR-UNIQUE-BUCKET-NAME-tfstate"
    prefix = "acme-sampleapp/state"
  }
}
```

**Commands run:**
```bash
terraform init
# answered "yes" to migrate local state → GCS backend
```

**Verified:** `.tfstate` object appeared under the prefix in the GCS bucket; updates on
subsequent `apply` runs.

**Key takeaway:** `init` connects to the backend *before* any resource is touched — this is
why the backend bucket can't be created by the same config that uses it as a backend
(chicken-and-egg: `init` needs the bucket to already exist). Bucket must be created out of
band (manually or via a separate bootstrap config).

---

## Lab 3 — Implicit Dependency (IAM Binding)

**Concept:** Terraform infers ordering automatically when one resource references another
resource's attribute — no `depends_on` needed.

**Code added:**
```hcl
resource "google_project_iam_member" "sa_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.gsa.email}"
}
```

**Commands run:**
```bash
terraform plan
terraform apply
terraform state list
```

**Verified:** IAM & Admin → IAM → `acme-web-app@...` shows `Cloud SQL Client` role.

**Key takeaway:** Referencing `google_service_account.gsa.email` inside this block is what
creates the implicit dependency — Terraform must create the SA first to know its real email
before building the IAM member string. This also drives destroy order (reverse of create
order).

---

## Lab 4 — `count` (indexed multiple resources)

**Concept:** `count` creates N copies of a resource block, addressed by numeric index.

**Code:**
```hcl
variable "environments" {
  type    = list(string)
  default = ["dev", "staging"]
}

resource "google_service_account" "env_sa" {
  count        = length(var.environments)
  account_id   = "acme-${var.environments[count.index]}"
  display_name = "SA for ${var.environments[count.index]} env"
}
```

**Commands run:**
```bash
terraform plan
terraform apply
terraform state list
```

**Verified:** `acme-dev`, `acme-staging` SAs created; state shows
`google_service_account.env_sa[0]` and `[1]`.

**Key takeaway:** Each index is a distinct resource instance in state. Removing an item from
the middle of the list shifts every subsequent index — Terraform sees this as
destroy+recreate for shifted resources, not just the removed one. (This is the flaw Lab 5
fixes.)

---

## Lab 5 — `for_each` (keyed multiple resources)

**Concept:** `for_each` addresses resource instances by stable key instead of fragile index —
avoids the count-shift problem.

**Code (replaced Lab 4 block):**
```hcl
variable "environments" {
  type    = set(string)
  default = ["dev", "staging"]
}

resource "google_service_account" "env_sa" {
  for_each     = var.environments
  account_id   = "acme-${each.value}"
  display_name = "SA for ${each.value} env"
}
```

**Commands run:**
```bash
terraform plan
terraform apply
terraform state list
```

**Test performed:** Removed `"dev"` from the set, leaving `["staging"]`, then re-ran
`terraform plan`.

**Verified:** Only `env_sa["dev"]` was marked for destroy — `env_sa["staging"]` was
untouched. Confirms `for_each` isolates changes per-key instead of shifting indices.

**Key takeaway:** Prefer `for_each` over `count` whenever items can be added/removed from
the middle of a collection. Reserve `count` for simple "N identical copies" or conditional
0/1 patterns.

---

## Lab 6 — State Surgery: `mv`, `rm`, `import`

**Concept:** Commands for reconciling config/state/reality when they drift apart —
renaming resources, orphaning them intentionally, and re-adopting existing cloud resources.

**6a — Rename without destroy:**
```bash
# after renaming resource label gsa -> backend_sa in .tf code
terraform state mv google_service_account.gsa google_service_account.backend_sa
terraform plan   # should show no changes
```

**6b — Remove from state (real resource untouched):**
```bash
terraform state rm google_service_account.backend_sa
terraform state list
terraform plan   # now wants to "create" — will fail, already exists
```

**6c — Re-adopt via import:**
```bash
terraform import google_service_account.backend_sa \
  projects/YOUR_PROJECT_ID/serviceAccounts/acme-web-app@YOUR_PROJECT_ID.iam.gserviceaccount.com
terraform plan   # should show no changes again
```

**Verified:** Status — done, results confirmed working as expected.

**Key takeaway:** `state mv` = rename in Terraform's ledger without touching real infra.
`state rm` = forget a resource (real thing untouched, now unmanaged). `import` = bind an
existing real resource to a config address. These three are the core toolkit for fixing
drift between code, state, and reality without destructive recreation.

---

## Lab 7 — Data Sources

**Concept:** `data` blocks read existing resources (created outside this config, or by
another config) without managing their lifecycle — no create/update/destroy, just read.
Resolved during `plan` via a direct API call.

**Code:**
```hcl
data "google_project" "current" {
  project_id = var.project_id
}

output "project_number" {
  value = data.google_project.current.number
}

data "google_compute_network" "default" {
  name = "default"
}

output "default_network_self_link" {
  value = data.google_compute_network.default.self_link
}
```

**Commands run:**
```bash
terraform plan
terraform apply
terraform output project_number
terraform output default_network_self_link
```

**Verified:**
```
project_number             = "999543194632"
default_network_self_link  = "https://www.googleapis.com/compute/v1/projects/my-devops-journey-502420/global/networks/default"
```

**Key takeaway:** Data sources show as reads in `plan`, never as create/destroy. Use them
to reference infra you don't own/manage in this config (existing networks, projects, IAM
policies, etc.) instead of hardcoding IDs.

---

## Lab 8 — `locals` (computed/derived values)

**Concept:** `locals` compute a value once inside the config and let you reuse it —
unlike `variable`, they're never set from outside (no `.tfvars`, no CLI flags), only
derived from other values.

**Code:**
```hcl
locals {
  name_prefix = "acme"
  common_labels = {
    project     = var.project_id
    managed_by  = "terraform"
    environment = "sandbox"
  }
}

resource "google_service_account" "gsa" {
  account_id   = "${local.name_prefix}-web-app"
  display_name = "My Test App"
}

resource "google_storage_bucket" "demo" {
  name                        = "${local.name_prefix}-demo-${var.project_id}"
  location                    = "US"
  labels                      = local.common_labels
  uniform_bucket_level_access = true
}
```

**Commands run:**
```bash
terraform plan
terraform apply
```

**Error hit + fixed:** `Error 412: constraints/storage.uniformBucketLevelAccess` — org
policy blocks legacy ACL buckets. Fixed by explicitly setting
`uniform_bucket_level_access = true`. Same category as the earlier disabled-SA-key-creation
policy — an org policy constraint, not a Terraform bug. When `apply` fails with
`Error 412` + `constraints/...`, the fix is almost always one extra field matching the
policy's requirement.

**Verified:** Bucket created with `project`, `managed_by`, `environment` labels visible in
console under Cloud Storage → bucket → Labels tab.

**Key takeaway:** `locals` reduce repeated expressions across resources. Refactoring an
existing resource to reference a `local` instead of a literal/inline expression should
produce a **no-op plan** if the computed value is identical — a good way to confirm a
refactor didn't accidentally change real infrastructure.

---

## Lab 9 — Modules (packaging reusable infra)

**Concept:** A module is a directory of `.tf` files treated as a reusable unit — inputs in,
resources created, outputs out. The main working directory is always the "root module";
anything under it referenced via `module "name" { source = "./path" }` is a **child module**.

**Structure:**
```
acme-sampleapp/
├── main.tf              (root — calls the module)
├── variables.tf
├── outputs.tf
└── modules/
    └── service_account/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

**`modules/service_account/variables.tf`:**
```hcl
variable "account_id" {
  type = string
}

variable "display_name" {
  type = string
}

variable "project_id" {
  type = string
}
```

**`modules/service_account/main.tf`:**
```hcl
resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
}
```

**`modules/service_account/outputs.tf`:**
```hcl
output "email" {
  value = google_service_account.this.email
}

output "account_id" {
  value = google_service_account.this.account_id
}
```

**Root `main.tf` addition:**
```hcl
module "backend_sa" {
  source       = "./modules/service_account"
  project_id   = var.project_id
  account_id   = "${local.name_prefix}-web-app-v2"
  display_name = "My Test App v2 (via module)"
}

output "backend_sa_email" {
  value = module.backend_sa.email
}
```

**Commands run:**
```bash
terraform init
terraform plan
terraform apply
terraform state list
```

**Verified:** `terraform state list` includes
`module.backend_sa.google_service_account.this` — module-created resources get a
`module.<name>.` prefix in state addressing, distinguishing them from root-level resources.

**Key takeaway:** Modules are just parameterized, reusable resource groupings. Inputs come
in via `variable` blocks (set by the caller), outputs go out via `output` blocks (read by
the caller as `module.<name>.<output>`). State addressing nests under `module.<name>.`.

---

## Lab 10 — Workspaces (multi-environment state isolation)

**Concept:** Workspaces let one config manage multiple **isolated state files** — same
code, separate state per environment — without duplicating `.tf` files.

**Commands:**
```bash
terraform workspace list          # shows "default" (used so far)
terraform workspace new dev
terraform workspace new staging
terraform workspace list          # * marks current workspace
terraform workspace select dev
```

**Code — reference `terraform.workspace` (built-in, no variable needed):**
```hcl
resource "google_storage_bucket" "workspace_demo" {
  name                        = "${local.name_prefix}-${terraform.workspace}-demo-${var.project_id}"
  location                    = "US"
  uniform_bucket_level_access = true
  labels                      = local.common_labels
}
```

**Commands run:**
```bash
terraform plan
terraform apply
terraform workspace select staging
terraform plan     # wants to CREATE again — staging has its own empty state
terraform apply
terraform state list   # only shows staging's resources
terraform workspace select dev
terraform state list   # only shows dev's resources
```

**Verified:** Two separate buckets created — `acme-dev-demo-...` and
`acme-staging-demo-...` — each tracked only in its own workspace's state.

**Key takeaway:** Each workspace = same code, fully separate state. Switching workspaces
switches which state file `plan`/`apply` reads and writes — resources in one workspace are
invisible to another. **Real-world caveat:** workspaces don't let you vary provider config
(e.g. different GCP projects per environment) cleanly, so most production repos use
separate backend prefixes/directories per environment instead. Workspaces are worth
knowing for the isolation concept, but not always the production pattern.

---

## Up Next

### Remaining Lab Plan

**Lab 11 — Import + Drift Detection**
- Create a resource manually in GCP console (outside Terraform).
- `terraform plan` on existing config — observe Terraform is blind to it (no drift shown,
  since it doesn't know the resource exists).
- Manually change an attribute of a Terraform-managed resource via console (e.g. rename a
  bucket's label) — run `terraform plan` — observe Terraform **does** detect this as drift
  (config says X, real world says Y) and proposes to revert it back to match config.
- Contrast: unmanaged resources = invisible to Terraform. Managed resources = drift-detected
  and auto-corrected on next apply.

**Lab 12 — `dynamic` blocks**
- Generate repeated nested blocks (e.g. multiple `binding` entries in an IAM policy, or
  multiple lifecycle rules on a bucket) from a list/map, instead of writing each by hand.
- Uses `google_storage_bucket` lifecycle rules or `google_project_iam_policy` bindings as
  the concrete example.

**Lab 13 — `for_each` over modules**
- Take the `service_account` module from Lab 9 and call it multiple times via `for_each`
  (e.g. one SA per environment) instead of one hardcoded `module` block per SA.
- Shows module addressing in state: `module.backend_sa["dev"]`, `module.backend_sa["staging"]`.

**Lab 14 — Provider aliasing (multi-region / multi-project)**
- Configure a second `provider "google"` block with an `alias`, pointing at a different
  region (or project, if a second one is available).
- Create a resource explicitly using the aliased provider via `provider = google.alias_name`.
- Useful for real multi-region GKE/Cloud SQL setups.

**Lab 15 — `terraform.tfvars` + variable precedence**
- Move hardcoded values (project_id, environments list) into a `terraform.tfvars` file.
- Demonstrate precedence order: CLI `-var` flag > `*.auto.tfvars` > `terraform.tfvars` >
  `variable "..." { default = ... }`.
- Add a `.gitignore` entry for `*.tfvars` if it contains sensitive values.

**Lab 16 — Lifecycle meta-argument (`create_before_destroy`, `prevent_destroy`, `ignore_changes`)**
- Add `prevent_destroy = true` to a critical resource (e.g. the SA), attempt `terraform
  destroy`, observe the guard rail.
- Add `ignore_changes` to a field that gets modified outside Terraform (e.g. labels added
  by another automation) so Terraform stops fighting over it.

**Lab 17 — Provisioners & `null_resource`** *(brief — modern Terraform discourages these,
but worth recognizing since they show up in older/real repos)*
- Recognize `local-exec` / `remote-exec` provisioners and when they're a smell (should
  usually be replaced by cloud-init, startup scripts, or separate config-management tools).

**Lab 18 — Capstone: tie it together in your real `acme-sampleapp` repo**
- Apply everything (modules, for_each, locals, remote state, lifecycle rules) to the actual
  GKE/Cloud SQL/Workload Identity resources in your production learning repo, not just the
  sandbox examples used in Labs 1–17.

---

Labs 1–10 are complete and documented above. Labs 11–18 will be added to this file as each
is completed, following the same format (Concept → Code → Commands run → Verified → Key
takeaway).

