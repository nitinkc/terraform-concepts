# 1 — Execution Model, Providers & Authentication

**Code:** `01-basics/7-version-constraints/` · `02-gcp-terraform/z-core-gcp-resources/main.tf` · **Quiz:** [Providers & Auth](../quiz/01-providers-and-auth.md)

---

## Architect's Points to Keep in Mind

### 1. The Three-Way Reconciliation Model
Every `terraform plan` compares **three** sources of truth:

| Source | Role |
|---|---|
| **HCL (`.tf` files)** | Desired end state |
| **State (`terraform.tfstate`)** | What Terraform believes it owns from the last run |
| **Live Cloud API** | Actual reality fetched during the `refresh` phase |

- **HCL always wins.** Manual console edits create drift that the next `apply` reverts to match HCL.
- **Core vs. Provider split:**
    - **Terraform Core** (the CLI binary) knows HCL syntax, the dependency graph (DAG), state management, and meta-arguments (`count`, `for_each`, `depends_on`, `lifecycle`, `provider`). It knows *nothing* about cloud APIs.
    - **Provider Plugins** (e.g., `hashicorp/google`) own resource schemas, API calls, and whether a field change is an in-place `PATCH` or a destructive `ForceNew` replacement.

### 2. `required_providers` vs. `provider {}` (Interview Classic)
They look similar, live in different blocks, and run at different lifecycle stages:

| Block | Purpose | Evaluated During | Required? |
|---|---|---|---|
| `required_providers` (in `terraform {}`) | Declares plugin source (`hashicorp/google`) and version constraint | `terraform init` | **Always** for every provider used |
| `provider "<name>" {}` | Configures runtime settings (project, region, alias, credentials) | `plan` / `apply` | **Optional** if provider needs no config (`local`, `random`) or resources set their own args |

- **Provider-block `project`/`region`/`zone` are fallback defaults only.** If every resource in a module explicitly sets `project = var.project_id`, the `project` argument in `provider "google" {}` is never read. Removing it is a no-op.
- **Unused providers in `required_providers`** (e.g., declaring `hashicorp/random` when no `random_*` resource exists) still force plugin downloads on every `init` — clean them up.

### 3. `terraform init`, Version Constraints & `.terraform.lock.hcl`

- **`init` never touches `terraform.tfstate`.** It only downloads provider binaries into `.terraform/`, initializes the backend, and writes `.terraform.lock.hcl`. It is idempotent and safe to run at any time.
- **Constraint vs. Lock:**
    - **Constraint (`version = "~> 8.0"`)**: range of *acceptable* versions written by you.
    - **Lock file (`.terraform.lock.hcl`)**: exact version and cryptographic checksums *chosen* by `init`.
- **Commit `.terraform.lock.hcl` to Git; gitignore `.terraform/`.** Binaries in `.terraform/` are OS/architecture-specific, so teammates and CI runners still run `terraform init` to download their platform's binary pinned to the lock file's exact version.
- **Pessimistic constraint operator (`~>`):**only the **last digit** specified is allowed to increment:
    - `~> 2.4.1` means `>= 2.4.1, < 2.5.0` (patch updates only).
    - `~> 2.4` means `>= 2.4.0, < 3.0.0` (minor updates allowed).
- **`terraform init` vs `terraform init -upgrade`:** plain `init` strictly honors `.terraform.lock.hcl`; `-upgrade` re-resolves the newest version allowed by the constraint and updates the lock file.
- **Pinning the CLI:** `required_version = ">= 1.7, < 2.0"` inside `terraform {}` prevents syntax errors when a config uses newer language features (`moved`, `import` blocks, `optional()`).

### 4. GCP Authentication Precedence
Credentials should be ambient — **never hardcode keys in HCL**. The `google` provider evaluates credentials in this order (highest priority first):

1. `credentials` field inside `provider "google" {}` (avoid in production).
2. `GOOGLE_CREDENTIALS` / `GOOGLE_APPLICATION_CREDENTIALS` environment variables (CI runners / WIF credential config files).
3. **Application Default Credentials (ADC)**: `~/.config/gcloud/application_default_credentials.json`, created via `gcloud auth application-default login`. Stores a long-lived OAuth **refresh token**; client libraries automatically exchange it for 1-hour **access tokens**.
4. **Compute/GKE Metadata Server**: attached Service Account when running inside GCP (GCE, GKE Workload Identity, Cloud Build).

### 5. Provider Aliasing (Multi-Region / Multi-Project)

- The `provider` block **without** an `alias` is the default provider.
- Add `alias = "us_east"` on a second `provider "google"` block and route resources via `provider = google.us_east` (reference identifier, **no quotes**).
- **Module rule:** Child modules inherit default providers automatically, but **never** inherit aliased providers implicitly. Pass them explicitly via `providers = { google = google.us_east }` on the `module` block. Child modules must never declare their own `provider {}` configuration blocks.

---

## Code Reference

=== "Local (`01-basics/7-version-constraints`)"

    ```hcl
    terraform {
      required_providers {
        local = {
          source  = "hashicorp/local"
          version = "~> 2.4.1" # >= 2.4.1, < 2.5.0 (patch only)
        }
      }
    }

    # Optional for `local` — takes no configuration options
    provider "local" {}

    resource "local_file" "pet" {
      filename        = "/tmp/hello.txt"
      content         = "Pinned provider test"
      file_permission = "0700"
    }
    ```

=== "GCP Root + Aliasing (`02-gcp-terraform/`)"

    ```hcl
    terraform {
      required_version = ">= 1.7, < 2.0"

      required_providers {
        google = {
          source  = "hashicorp/google"
          version = "~> 8.0" # >= 8.0, < 9.0
        }
      }
    }

    # Default provider (unaliased)
    provider "google" {
      project = var.project_id
      region  = "us-central1"
    }

    # Secondary aliased provider for multi-region resources
    provider "google" {
      alias   = "us_east"
      project = var.project_id
      region  = "us-east1"
    }

    resource "google_storage_bucket" "east_region_demo" {
      provider                    = google.us_east # unquoted reference
      name                        = "acme-east-${var.project_id}"
      location                    = "US-EAST1"
      uniform_bucket_level_access = true
    }

    module "east_service" {
      source    = "./modules/service"
      providers = { google = google.us_east } # explicit pass required for modules
    }
    ```

=== "CLI Cheatsheet"

    ```bash
    # Authenticate local ADC (writes OAuth refresh token)
    gcloud auth application-default login
    gcloud config set project YOUR_PROJECT_ID

    # Initialize & inspect locked versions
    terraform init
    cat .terraform.lock.hcl

    # Upgrade providers within version constraints & review diff
    terraform init -upgrade
    git diff .terraform.lock.hcl
    ```
