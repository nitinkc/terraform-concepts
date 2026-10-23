# 8 — Data Sources, Outputs & Module Design

**Code:** `01-basics/6-data-sources/` · `02-gcp-terraform/z-core-gcp-resources/data.tf`, `outputs.tf`, `modules/` · **Quiz:** [Resources, State & Drift](../quiz/02-resources-state-and-drift.md), [Providers & Auth](../quiz/01-providers-and-auth.md)

---

## Architect's Points to Keep in Mind

### 1. `resource` vs. `data` (High-Frequency Interview Comparison)
| Dimension | `resource` Block | `data` Block |
|---|---|---|
| **Ownership** | Full lifecycle (Create, Read, Update, Delete) | **Read-only query** against an external/existing object |
| **When Evaluated** | Refreshed on `plan`, mutated on `apply` | **Queried live from the API on every `plan` and `apply`** |
| **If Deleted Outside Terraform** | `plan` detects drift and proposes **recreating** it | `plan` **fails immediately with a Not Found error** — never falls back to stale state |
| **`terraform destroy` Effect** | Deletes the real cloud resource | Removes state cache entry only; **real object is untouched** |

- **External Availability Dependency:** Because `data` sources query live on every run (never serving a cached value from state unless `-refresh=false` is explicitly passed), every `data` block makes your `plan` dependent on that external API/object being reachable.
- **Why `data "google_client_config" "default"` Must Be a Data Source:**
  - GCP OAuth2 access tokens expire every **1 hour**.
  - A `resource` only updates during `apply` if drift is detected, which would leave downstream `kubernetes` and `helm` providers with an expired token on subsequent plans.
  - A `data` source re-fetches a fresh access token live on every single `plan` and `apply`.

### 2. Outputs: Public Interface & CLI Extraction
- Outputs are a root or child module's **public API** — anything not exported in an `output` block is private encapsulated state.
- **CLI Extraction (`-raw` vs. `-json`):**
  - `terraform output -raw <name>` strips quotes for shell scripts (`export SA=$(terraform output -raw email)`), but **only works on primitive values** (`string`, `number`, `bool`).
  - Calling `-raw` on a `map`, `list`, or `object` fails. Use `terraform output -json <name> | jq -r '.key'` for structured outputs.
- **Plaintext State & Sensitive Contagion:**
  - Every output value is stored in **plaintext** in `terraform.tfstate`.
  - If an output references any `sensitive` variable or resource attribute, Terraform fails validation unless the `output` block also declares `sensitive = true`.

### 3. Module Architecture & Encapsulation Rules
- **Root module:** the working directory where you run `terraform init`/`apply`.
- **Child module:** a directory invoked via `module "<name>" { source = "..." }`.
- **Strict Scope Boundary:** A parent root can only pass inputs declared in the child's `variables.tf` and read values exported in the child's `outputs.tf`. Neither can read the other's `locals` or unexported resources directly.
- **State Addressing & Refactoring Trap:**
  - Resources inside a child module are addressed as `module.<module_name>.<resource_type>.<local_name>` (commonly named `this` inside single-resource-class modules: `module.backend_sa.google_service_account.this`).
  - **Extracting an existing root resource into a child module changes its state address** → Terraform plans a **Destroy + Create** unless you add a `moved { from = ... to = module.x... }` block or run `terraform state mv`.
- **Module Sources & Versioning:**
  - Local path (`./modules/gcp-vm`): evolves in lockstep with the repo; re-read directly.
  - Remote Git/Registry (`git::https://...//modules/vpc?ref=v1.4.0`): cached in `.terraform/modules/` during `init`. Always pin tags/versions; upgrading requires `terraform init -upgrade`.
- **Architect's Heuristics — When NOT to Write a Module:**
  1. **Never wrap a single resource** unless enforcing mandatory org-wide security defaults.
  2. **Require at least 2 callers** before abstracting (1 caller = unnecessary indirection).
  3. **Keep environment conditionals out of child modules** — filter maps in the caller's `locals` and `for_each` the module from the outside.

### 4. Declarative vs. Imperative Escape Hatches (`archive_file` vs. `null_resource`)
- **`data "archive_file"` (Safe Declarative Escape):** Zips local source directories during `plan` and exposes `output_md5` / `output_base64sha256`. Feeding `output_md5` into a Cloud Function or object name integrates local file changes directly into the Terraform DAG.
- **`null_resource` / `terraform_data` + `provisioner "local-exec"` (Imperative Last Resort):**
  - Runs arbitrary shell commands on the machine executing Terraform; only re-runs when its `triggers` map changes.
  - **Code Smell & Security Risk:** Untracked by state diffing, marks resources tainted on failure, and is the primary **CI/CD PR arbitrary code execution exploit vector** (see [§10](10-architecture-multirepo-gke-and-cicd.md)). Prefer cloud-init, startup scripts, or Kubernetes Jobs.

---

## Code Reference

=== "Local (`01-basics/6-data-sources`, `archive_file`, `null_resource`)"

    ```hcl
    # 1. Data source vs Resource ownership
    data "local_file" "external" {
      filename = "/tmp/my_file.txt" # Must already exist on disk; never deleted on `destroy`
    }

    resource "local_file" "managed" {
      filename = "/tmp/hello.txt"
      content  = data.local_file.external.content
    }

    # 2. Declarative zip bundle with hash tracking
    data "archive_file" "bundle" {
      type        = "zip"
      source_dir  = "/tmp/tf-practice"
      output_path = "/tmp/tf-practice-bundle.zip"
    }

    output "bundle_md5" {
      value = data.archive_file.bundle.output_md5
    }

    # 3. Imperative provisioner (last resort — re-runs only when `triggers` changes)
    resource "null_resource" "notify" {
      triggers = {
        bundle_hash = data.archive_file.bundle.output_md5
      }
      provisioner "local-exec" {
        command = "echo Bundled hash: ${self.triggers.bundle_hash}"
      }
    }
    ```

=== "GCP Data Sources, Outputs & Child Module (`02-gcp-terraform/z-core-gcp-resources`)"

    ```hcl
    # data.tf — Query existing GCP project & default VPC without owning them
    data "google_project" "current" {
      project_id = var.project_id
    }

    data "google_compute_network" "default" {
      name = "default"
    }

    # Live OAuth token for downstream Kubernetes/Helm providers (expires hourly)
    data "google_client_config" "default" {}

    # modules/gcp-vm/main.tf — Reusable child module
    resource "google_compute_instance" "vm" {
      name         = var.instance_name
      machine_type = var.machine_type
      zone         = var.zone

      boot_disk {
        initialize_params { image = "debian-cloud/debian-11" }
      }
      network_interface {
        subnetwork = var.subnetwork_id
      }
    }

    # modules/gcp-vm/outputs.tf
    output "instance_ip" {
      value = google_compute_instance.vm.network_interface[0].network_ip
    }

    # compute.tf (Root caller)
    module "fde_vm" {
      source        = "./modules/gcp-vm"
      instance_name = "fde-app-server"
      machine_type  = "e2-medium"
      zone          = "us-central1-a"
      subnetwork_id = google_compute_subnetwork.subnet.id
    }

    # outputs.tf — Structured output vs Primitive output
    output "server_internal_ip" {
      value = module.fde_vm.instance_ip # Read with: terraform output -raw server_internal_ip
    }

    output "service_account" {
      value = {
        id    = google_service_account.gsa.account_id
        email = google_service_account.gsa.email
      }
      # Read with: terraform output -json service_account | jq -r '.email'
    }
    ```
