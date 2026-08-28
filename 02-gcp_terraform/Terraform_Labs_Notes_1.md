# Terraform Learning — Lab Notes (acme-sampleapp)

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

**`test/modules/service_account/variables.tf`:**
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

**`test/modules/service_account/main.tf`:**
```hcl
resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.account_id
  display_name = var.display_name
}
```

**`test/modules/service_account/outputs.tf`:**
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
   source       = "test/modules/service_account"
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

## Lab 11 — Import + Drift Detection

**Concept:** Three-part lab covering:
- (a) Terraform is blind to resources it doesn't manage, 
- (b) drift detection reverts manual changes on managed resources back to match code, 
- (c) `import` binds an existing unmanaged resource into state.

**Part A — Unmanaged resource (created outside Terraform):**
```bash
gsutil mb -l us-central1 gs://acme-manual-bucket-YOUR_PROJECT_ID
terraform plan
```
Expected: plan shows **no changes** — bucket isn't in config/state, so it's invisible to
Terraform.

**Part B — Drift on a managed resource:**
Manually edit a label (e.g. `environment`) on an existing Terraform-managed bucket
(from Lab 8/10) via console, then:
```bash
terraform plan   # shows an update reverting the label back to code's value
terraform apply  # reverts it in the real bucket
```
Expected: drift detected, code wins, real world corrected back to match config.

**Part C — Import the manually-created bucket:**
```hcl
resource "google_storage_bucket" "manual_import" {
  name                        = "acme-manual-bucket-YOUR_PROJECT_ID"
  location                    = "US"
  uniform_bucket_level_access = true
}
```
```bash
terraform import google_storage_bucket.manual_import acme-manual-bucket-YOUR_PROJECT_ID
terraform plan
```
Watch for a `location` mismatch (created as `us-central1`, code says `US`) — a good
demonstration that `import` only binds state; it does not validate or correct your HCL
against reality. Any mismatch surfaces as a plan diff you must resolve yourself.

**Status:** *Not yet run — pending your results.*

**Key takeaway (expected):** Unmanaged = invisible to Terraform (no drift shown at all).
Managed = drift-detected and auto-corrected toward code on next apply. `import` only
populates state — you're responsible for making the HCL attributes actually match the real
resource, or the very next plan will show a diff.

---

## Lab 12 — `dynamic` Blocks

**Concept:** `dynamic` generates repeated nested blocks (not top-level resources) from a
list/map — e.g. multiple lifecycle rules inside one bucket, or multiple bindings inside one
IAM policy — instead of writing each nested block by hand.

**Code — multiple lifecycle rules on a bucket, generated from a list:**
```hcl
locals {
  lifecycle_rules = [
    { age = 30, storage_class = "NEARLINE" },
    { age = 90, storage_class = "COLDLINE" },
    { age = 365, storage_class = "ARCHIVE" },
  ]
}

resource "google_storage_bucket" "lifecycle_demo" {
  name                        = "${local.name_prefix}-lifecycle-${var.project_id}"
  location                    = "US"
  uniform_bucket_level_access = true

  dynamic "lifecycle_rule" {
    for_each = local.lifecycle_rules
    content {
      condition {
        age = lifecycle_rule.value.age
      }
      action {
        type          = "SetStorageClass"
        storage_class = lifecycle_rule.value.storage_class
      }
    }
  }
}
```

**Commands to run:**
```bash
terraform plan
terraform apply
```

**To verify:** Cloud Storage → bucket → Lifecycle tab → confirm 3 rules present, matching
the 30/90/365-day transitions.

**Status:** *Not yet run — pending your results.*

**Key takeaway (expected):** `dynamic "<block_name>"` + `for_each` + `content {}` is the
pattern for generating repeated *nested* blocks — different from resource-level `for_each`
(Lab 5), which generates repeated *whole resources*. Use `dynamic` when the repetition is
inside one resource, not across separate resource instances.

---

## Lab 13 — `for_each` Over Modules

**Concept:** Apply `for_each` to a `module` call itself (not just a resource) — one module
invocation per key, instead of one hardcoded `module` block per instance.

**Code — replace the single Lab 9 module call with a keyed set:**

```hcl
variable "service_accounts" {
   type = map(object({
      account_id   = string
      display_name = string
   }))
   default = {
      dev = {
         account_id   = "acme-dev-app"
         display_name = "Dev App SA"
      }
      staging = {
         account_id   = "acme-staging-app"
         display_name = "Staging App SA"
      }
   }
}

module "app_sa" {
   source       = "test/modules/service_account"
   for_each     = var.service_accounts
   project_id   = var.project_id
   account_id   = each.value.account_id
   display_name = each.value.display_name
}

output "app_sa_emails" {
   value = {for k, m in module.app_sa : k => m.email}
}
```

**Commands to run:**
```bash
terraform plan
terraform apply
terraform state list
terraform output app_sa_emails
```

**To verify:** `terraform state list` shows `module.app_sa["dev"].google_service_account.this`
and `module.app_sa["staging"].google_service_account.this`. Console shows both SAs created.

**Status:** *Not yet run — pending your results.*

**Key takeaway (expected):** Module state addressing nests the `for_each` key the same way
resource `for_each` does: `module.<name>["<key>"]`. The `output` uses a `for` expression to
build a map from each module instance's own output — a common pattern for surfacing
per-instance values when using `for_each` over modules.

---

## Lab 14 — Provider Aliasing (Multi-Region / Multi-Project)

**Concept:** A second `provider "google"` block with an `alias` lets you target a different
region/project from within the same config, and explicitly route specific resources to it
via `provider = google.<alias>`.

**Code:**
```hcl
provider "google" {
  alias   = "us_east"
  project = var.project_id
  region  = "us-east1"
}

resource "google_storage_bucket" "east_region_demo" {
  provider                    = google.us_east
  name                        = "${local.name_prefix}-east-${var.project_id}"
  location                    = "US-EAST1"
  uniform_bucket_level_access = true
}
```

**Commands to run:**
```bash
terraform plan
terraform apply
```

**To verify:** Cloud Storage → bucket → confirm location is `US-EAST1`, distinct from your
other buckets (created via the default, unaliased `us-central1` provider).

**Status:** *Not yet run — pending your results.*

**Key takeaway (expected):** Without `provider = google.<alias>` on a resource, it uses the
default (unaliased) provider block. Aliasing is the mechanism behind real multi-region or
multi-project setups (e.g. a GKE cluster's primary and DR region, or resources split across
two GCP projects) — one config, multiple provider configurations, explicit routing per
resource.

---

## Lab 15 — `terraform.tfvars` + Variable Precedence

**Concept:** Move hardcoded values into a `.tfvars` file instead of relying on `default`,
and observe Terraform's variable precedence order in practice.

**Code — `terraform.tfvars`:**
```hcl
project_id   = "my-devops-journey-502420"
environments = ["dev", "staging"]
```

**`.gitignore` addition (if any value here were ever sensitive):**
```
*.tfvars
!*.auto.tfvars.example
```

**Commands to run — prove precedence:**
```bash
terraform plan
# uses terraform.tfvars value

terraform plan -var="project_id=override-project"
# CLI flag wins — highest precedence

echo 'project_id = "auto-project"' > prod.auto.tfvars
terraform plan
# *.auto.tfvars wins over plain terraform.tfvars
```

**Status:** *Not yet run — pending your results.*

**Key takeaway (expected):** This lab directly demonstrates, hands-on, the precedence order
already documented in `Terraform_Theory_Reference.md` §4: CLI flag > `*.auto.tfvars` >
`terraform.tfvars` > `variable { default }`. Running each command in sequence and watching
which value plan resolves to converts that memorized ordering into observed behavior.

---

## Lab 16 — Lifecycle Meta-Arguments

**Concept:** `lifecycle {}` block controls how Terraform handles specific resources outside
normal create/update/destroy logic — guarding against destroys, or telling Terraform to stop
fighting over fields changed outside its control.

**Code — `prevent_destroy`:**
```hcl
resource "google_service_account" "gsa" {
  account_id   = "${local.name_prefix}-web-app"
  display_name = "My Test App"

  lifecycle {
    prevent_destroy = true
  }
}
```

**Commands to run:**
```bash
terraform apply             # apply with the guard in place
terraform destroy           # should fail with an explicit prevent_destroy error
```

**Code — `ignore_changes` (for a field modified outside Terraform, e.g. by another
automation adding labels):**
```hcl
resource "google_storage_bucket" "demo" {
  name                        = "${local.name_prefix}-demo-${var.project_id}"
  location                    = "US"
  uniform_bucket_level_access = true
  labels                      = local.common_labels

  lifecycle {
    ignore_changes = [labels]
  }
}
```

**Commands to run:**
```bash
terraform apply
# manually add/change a label via console
terraform plan   # should show NO changes now, despite drift on `labels`
```

**Status:** *Not yet run — pending your results.*

**Key takeaway (expected):** `prevent_destroy` is a safety rail for critical resources —
`terraform destroy` (or a plan that would replace the resource) errors out instead of
proceeding. `ignore_changes` tells Terraform to stop treating a specific field as
drift — useful when something outside Terraform (another automation, a human process)
legitimately owns that one field. Contrast with Lab 11 Part B, where drift *was* corrected —
`ignore_changes` is how you'd deliberately opt a field out of that correction behavior.

---

## Lab 17 — Provisioners & `null_resource` (brief)

**Concept:** `local-exec`/`remote-exec` provisioners run arbitrary shell commands as part of
apply. Modern Terraform guidance treats these as a last resort/code smell — most cases are
better solved with cloud-init/startup scripts or dedicated config-management tools. Worth
recognizing since they appear in older or real-world repos (including the security exploit
pattern already covered in `Terraform_Theory_Reference.md` §9 — a malicious PR using
`local-exec` to exfiltrate state).

**Code — minimal recognition example, not recommended for real use:**
```hcl
resource "null_resource" "example" {
  provisioner "local-exec" {
    command = "echo 'This runs on apply, outside any real GCP resource'"
  }
}
```

**Commands to run:**
```bash
terraform apply
```

**To verify:** the echoed string appears in your terminal output during apply.

**Status:** *Not yet run — pending your results.*

**Key takeaway (expected):** `null_resource` + a provisioner isn't tied to any real cloud
resource — it's a way to run arbitrary local/remote commands as a side effect of apply. This
is exactly the mechanism a malicious CI/CD PR could abuse (see theory reference, GitOps
security section) — good to recognize both as a legacy pattern and as an attack vector, not
to reach for by default in new code.

---

## Lab 18 — Capstone: Apply to Real `acme-sampleapp` Repo

**Concept:** Take every pattern practiced in the sandbox (Labs 1–17 — remote state, implicit
dependencies, `count`/`for_each`, data sources, locals, modules, workspaces, state surgery,
dynamic blocks, provider aliasing, variable precedence, lifecycle guards) and apply them to
the actual GKE/Cloud SQL/Workload Identity resources in your production learning repo,
rather than sandbox examples.

**Suggested approach:**
1. Re-read `acme-sampleapp`'s existing modules/resources with fresh eyes — identify which
   sandbox pattern each part maps to (e.g. its `locals` block ↔ Lab 8, its Consul `data`
   blocks ↔ Lab 7, any `for_each` over environments ↔ Lab 5/13).
2. Pick one real, low-risk resource in the repo (not GKE/Cloud SQL directly — something
   like an IAM binding or a bucket) and practice a full state-surgery cycle on it (Lab 6)
   in a sandboxed workspace/environment, not production.
3. Identify one place in the repo that could benefit from a `dynamic` block or
   `lifecycle { ignore_changes }` guard, and propose (don't necessarily apply) the change.

**Status:** *Not started — this is the wrap-up milestone once Labs 11–17 are complete.*

**Key takeaway (expected):** This lab isn't about new syntax — it's the transfer step
(Advisor persona's Gate 4/Gate 5 language): can the patterns learned in isolated, safe
sandbox examples be recognized and reasoned about inside a real, complex, multi-file
production-style repo.

---

## Up Next

Labs 1–10 are complete and documented above. Lab 11 is drafted, pending your run results.
Labs 12–18 are now fully drafted (code + commands + expected verification) above, each
marked "Not yet run" — update each lab's **Status** and **Key takeaway** sections with your
actual results as you complete them, same as Labs 1–10.