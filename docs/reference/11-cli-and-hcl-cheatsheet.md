# 11 — Master HCL, CLI & Glossary Cheatsheet

**Code:** `01-basics/cheatsheet/main.tf` · All `02-gcp-terraform/` roots

---

## 1. All-in-One Annotated HCL Template

```hcl
# ============================================================================
# 1. TERRAFORM & PROVIDERS (versions.tf / providers.tf / backend.tf)
# ============================================================================
terraform {
  required_version = ">= 1.7, < 2.0" # Pin CLI version

  required_providers {               # Read during `terraform init`
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.1"           # Patch updates only (>= 2.4.1, < 2.5.0)
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"             # Minor updates allowed (>= 8.0, < 9.0)
    }
  }

  backend "gcs" {                    # Partial config: pass bucket/prefix via -backend-config
    # bucket = "my-tfstate-bucket"
    # prefix = "app/state"
  }
}

provider "google" {                  # Default provider (read during plan/apply)
  project = var.project_id           # Fallback default if resource omits `project`
  region  = "us-central1"
}

provider "google" {                  # Aliased provider for multi-region/project
  alias   = "us_east"
  project = var.project_id
  region  = "us-east1"
}

# ============================================================================
# 2. VARIABLES & LOCALS (variables.tf / locals.tf)
# Precedence (low -> high): default < TF_VAR_x < terraform.tfvars < *.auto.tfvars < -var/-var-file
# ============================================================================
variable "project_id" {
  description = "Target GCP project ID"
  type        = string
}

variable "environments" {
  type    = set(string)              # Use `set(string)` or `map` for `for_each`
  default = ["dev", "staging"]

  validation {
    condition     = alltrue([for e in var.environments : contains(["dev", "staging", "prod"], e)])
    error_message = "Allowed environments: dev, staging, prod."
  }
}

variable "api_token" {
  type      = string
  sensitive = true                   # Masks CLI stdout only; still plaintext in state!
}

locals {                             # Block is plural `locals`, reference is singular `local.`
  name_prefix   = "acme-${terraform.workspace}"
  is_prod       = terraform.workspace == "prod"
  common_labels = { managed_by = "terraform", env = terraform.workspace }
}

# ============================================================================
# 3. DATA SOURCES (data.tf) — Queried LIVE on every plan/apply; never destroyed
# ============================================================================
data "google_project" "current" {
  project_id = var.project_id
}

data "google_client_config" "default" {} # Fresh 1-hour OAuth token on every run

# ============================================================================
# 4. RESOURCES, META-ARGUMENTS & MODULES (main.tf)
# ============================================================================
resource "google_service_account" "env_sa" {
  for_each     = var.environments    # Keyed state address: google_service_account.env_sa["dev"]
  account_id   = "${local.name_prefix}-${each.key}"
  display_name = "SA for ${each.value}"

  lifecycle {
    prevent_destroy       = false
    create_before_destroy = true
    ignore_changes        = [display_name] # Attribute identifiers, never quoted strings
  }
}

resource "google_project_iam_member" "sql_client" {
  for_each = google_service_account.env_sa # Chained `for_each` guarantees matching keys
  project  = var.project_id
  role     = "roles/cloudsql.client"
  member   = "serviceAccount:${each.value.email}" # Implicit dependency edge
}

resource "google_storage_bucket" "east_logs" {
  count                       = local.is_prod ? 1 : 0 # Conditional 0/1 list
  provider                    = google.us_east        # Route to aliased provider
  name                        = "${local.name_prefix}-east-logs-${var.project_id}"
  location                    = "US-EAST1"
  uniform_bucket_level_access = true

  dynamic "lifecycle_rule" {         # Repeats nested blocks inside 1 resource
    for_each = [{ age = 30, class = "NEARLINE" }, { age = 90, class = "COLDLINE" }]
    content {
      condition { age = lifecycle_rule.value.age }
      action {
        type          = "SetStorageClass"
        storage_class = lifecycle_rule.value.class
      }
    }
  }

  depends_on = [google_project_iam_member.sql_client] # Only for edges invisible to HCL
}

module "app_vm" {
  source    = "./modules/gcp-vm"
  providers = { google = google.us_east } # Aliased providers must be passed explicitly
  zone      = "us-east1-b"
}

# ============================================================================
# 5. OUTPUTS (outputs.tf)
# ============================================================================
output "sa_emails" {                 # Structured output -> read with `terraform output -json`
  value = { for k, sa in google_service_account.env_sa : k => sa.email }
}

output "east_bucket_name" {          # Safe read of `count = 0/1` resource via `one()`
  value = one(google_storage_bucket.east_logs[*].name)
}
```

---

## 2. Complete CLI Reference

### Core Lifecycle & Validation
| Command | Purpose |
|---|---|
| `terraform init` | Download provider plugins into `.terraform/`, initialize backend, write `.terraform.lock.hcl` |
| `terraform init -upgrade` | Re-resolve newest provider/module versions allowed by constraints and update lock file |
| `terraform init -migrate-state` | Reconfigure backend and interactively migrate existing state to the new backend |
| `terraform fmt -check -recursive` | Check canonical HCL formatting across all subdirectories (exits non-zero on drift) |
| `terraform validate` | Verify syntax, types, and attribute names offline (no API calls) |
| `terraform plan -out=tf.plan` | Refresh state, compute 3-way diff, and save an immutable execution plan artifact |
| `terraform apply tf.plan` | Execute an already-reviewed plan artifact without re-prompting |
| `terraform destroy` | Destroy all resources tracked in the current workspace's state (`data` sources untouched) |

### Targeting, Replacement & Variables
| Command | Purpose |
|---|---|
| `terraform plan -var="k=v"` | Override variable with highest CLI precedence |
| `terraform plan -var-file="prod.tfvars"` | Explicitly load a `.tfvars` file |
| `terraform plan -refresh=false` | Skip live API refresh; compute plan against cached state (emergency outage use only) |
| `terraform apply -replace=<addr>` | Force destroy + recreate of a specific resource instance (replaces `terraform taint`) |
| `terraform plan -target=<addr>` | Scope plan/apply to one resource/module and its upstream dependencies (debugging only) |

### State Inspection & Surgery
| Command | Purpose |
|---|---|
| `terraform state list` | List all resource addresses tracked in current state |
| `terraform state show <addr>` | Inspect all recorded attributes of a single resource in state |
| `terraform state mv <old> <new>` | Rename resource address in state without destroying/recreating real infra |
| `terraform state rm <addr>` | Remove resource from state management without deleting the real cloud resource |
| `terraform import <addr> <cloud_id>` | Bind an existing unmanaged cloud resource to an HCL address in state |
| `terraform state pull > state.json` | Download raw state JSON from remote backend to stdout |
| `terraform force-unlock <LOCK_ID>` | Break a stale backend mutex lock after verifying no other process is running |

### Outputs, Graph, Workspaces & Debugging
| Command | Purpose |
|---|---|
| `terraform output -raw <name>` | Print bare primitive output string (for shell variable assignment) |
| `terraform output -json <name>` | Print structured map/list output as JSON (pipe to `jq`) |
| `terraform console` | Interactive REPL to test `for`, `try()`, `jsondecode()`, and local expressions against state |
| `terraform graph \| dot -Tsvg > graph.svg` | Render the resource dependency DAG via Graphviz |
| `terraform workspace list / show / new / select` | Inspect, create, or switch isolated state workspaces |
| `TF_LOG=DEBUG TF_LOG_PATH=tf.log terraform plan` | Capture verbose provider/API HTTP traces to a file |

---

## 3. Architectural Glossary (One-Line Lookup)

| Term | Architect's Definition |
|---|---|
| **ADC** | Application Default Credentials (`~/.config/gcloud/application_default_credentials.json`); stores a long-lived OAuth refresh token used automatically by the `google` provider. |
| **Backend** | Storage + locking engine for `terraform.tfstate` (e.g., `local`, `gcs`); configured at `init` time and cannot interpolate variables. |
| **Blast Radius** | The set of resources sharing a single root module and `terraform.tfstate` file. |
| **Data Source (`data`)** | Read-only block queried live on every `plan`/`apply`; fails immediately if the target object is missing. |
| **Drift** | Divergence between live cloud reality and `terraform.tfstate` caused by out-of-band changes; corrected toward HCL on next `apply`. |
| **`dynamic` Block** | Repeats nested configuration blocks *inside* a single resource without creating multiple resource instances. |
| **Force Replacement (`ForceNew`)** | Provider schema rule requiring destroy + create when an immutable cloud attribute (e.g., `account_id`, `machine_type`) is modified. |
| **Guard Propagation** | Architectural requirement that every downstream `for_each` or reference consuming a conditionally filtered map must use the same filtered keyset or a null-safe wrapper (`try`/`one`). |
| **Implicit Dependency** | A DAG ordering edge automatically inferred by Terraform Core when Resource B references an attribute of Resource A. |
| **Lock File (`.terraform.lock.hcl`)** | Committed file recording exact provider versions and cryptographic hashes selected during `terraform init`. |
| **Meta-Argument** | Core-interpreted argument valid across all resource types: `count`, `for_each`, `depends_on`, `provider`, `lifecycle`. |
| **Workload Identity** | Keyless GKE authentication mechanism linking a Kubernetes `ServiceAccount` (via annotation) to a GCP IAM Service Account (via `roles/iam.workloadIdentityUser`). |
