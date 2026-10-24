# 9 — State Surgery, Drift, Import & Workspaces

**Code:** `02-gcp-terraform/3-acme-lab-step-by-step/` · `acme-sampleapp-.../backend/infra/` · **Quiz:** [Resources, State & Drift](../quiz/02-resources-state-and-drift.md)

---

## Architect's Points to Keep in Mind

### 1. The Four Ways State and Reality Diverge
| Divergence Type | What Happened | What `terraform plan` Shows | Repair Mechanism |
|---|---|---|---|
| **1. Drift** | Managed resource modified manually in Cloud Console | Diff (`~` or `-/+`) reverting cloud back to HCL | Run `terraform apply` (or update HCL if change was intentional) |
| **2. Unmanaged** | Resource created outside Terraform (`gcloud` / Console) | **Nothing** — Terraform only refreshes addresses in state | Write HCL block + `terraform import` |
| **3. State Loss / Orphan** | Resource exists in cloud, but is missing from `terraform.tfstate` | Proposes `+ create` (fails on apply with `409 AlreadyExists`) | `terraform import` (if healthy) or delete-and-recreate (if broken) |
| **4. Address Refactor** | Resource renamed or moved into a `module` in HCL | Proposes `- destroy` old address, `+ create` new address | `moved {}` block or `terraform state mv` |

### 2. State Surgery Toolkit (`mv`, `rm`, `import`)
None of these commands make mutating calls to cloud infrastructure — they only edit `terraform.tfstate`:

| Command / Block | State Effect | Real Cloud Resource | Primary Use Case |
|---|---|---|---|
| `terraform state mv <old> <new>` / `moved {}` | Renames address key | Untouched | Refactoring resource names or moving resources into modules |
| `terraform state rm <addr>` / `removed {}` | Deletes address entry | **Untouched (now orphaned/unmanaged)** | Handing ownership of a resource to another Terraform root, or retiring HCL without deleting live data |
| `terraform import <addr> <cloud_id>` / `import {}` | Binds existing cloud ID into state | Untouched (now managed) | Adopting brownfield resources or recovering from state loss |

!!! warning "Always Run `terraform plan` Immediately After Surgery"
    A successful `state mv` or `import` is only proven correct when the subsequent `terraform plan` reports **`No changes. Your infrastructure matches the configuration.`**

### 3. Three Properties of `import` That Trip Engineers Up

1. **`import` only populates state — it does not write HCL** (unless using Terraform 1.5+ `import {}` blocks with `terraform plan -generate-config-out=generated.tf`). For CLI `terraform import`, you must write the stub `resource` block first.
2. **`import` does not validate your HCL attributes against reality.** If the real GCS bucket is in `us-central1` and your HCL block says `location = "US"`, `terraform import` succeeds, and the **very next `terraform plan` proposes destroying and recreating the bucket** to match `"US"`. Always inspect the post-import `plan` and align your HCL before applying!
3. **Import IDs are provider-specific strings**, not HCL names (e.g., `projects/MY_PROJ/serviceAccounts/EMAIL`).

### 4. Incident Framework: `import` vs. Delete-and-Recreate
When an `apply` fails partway through (e.g., a `TLS handshake timeout` or partial cluster creation) and the next run hits `Error 409: AlreadyExists`:

1. **Verify before acting:** Check **both** `terraform state list` and live cloud health (`gcloud ... describe`). A transient network timeout on a post-create read-back may mean the resource is already healthy and/or tracked.
2. **Choose `import` when:** The resource is **healthy** in the cloud and holds state, data, or long provisioning time worth keeping.
3. **Choose Delete-and-Recreate (`gcloud ... delete` + `terraform apply`) when:** Creation failed mid-flight leaving the resource in a half-built/broken state (e.g., a GKE cluster that failed during initial node pool creation) and **nothing irreplaceable would be lost**. Importing a broken resource just imports drift.

### 5. Workspaces (`terraform.workspace`) & Production Caveats

- Every config starts in the `default` workspace. Creating a new workspace (`terraform workspace new dev`) creates an isolated state file (`terraform.tfstate.d/dev/terraform.tfstate` locally, or a separate object under the GCS `prefix`) sharing the exact same `.tf` code.
- **Two Production Caveats (Interview Gold):**
    1. **Why directory-per-env (`envs/dev/`, `envs/prod/`) usually beats workspaces:** Workspaces share a single backend block and don't naturally isolate credentials or separate GCP projects per environment; worse, target environment selection is invisible CLI state (`workspace select`), making it easy to accidentally apply to `prod`.
    2. **Naming conventions are not enforced by Terraform:** In `backend/infra`, `local.static_envs = ["dev", "qa"]` and `var.static_env` (a boolean) had no automatic link to `terraform.workspace`. Selecting the `dev` workspace did *not* automatically set `var.static_env = true` — unless code explicitly computes `contains(local.static_envs, terraform.workspace)`, Terraform treats them as unrelated values.

---

## Code Reference

=== "Local State Surgery (`01-basics`)"

    ```bash
    # 1. Rename resource in HCL (`local_file.pet` -> `local_file.greeting_file`), then move state:
    terraform state mv local_file.pet local_file.greeting_file
    terraform plan   # 0 changes

    # 2. Orphan resource from state (file remains on disk at /tmp/helloFruits.txt):
    terraform state rm local_file.greeting_file
    ls -la /tmp/helloFruits.txt

    # 3. Re-adopt resource into state and verify HCL alignment:
    terraform import local_file.greeting_file /tmp/helloFruits.txt
    terraform plan   # Fix any attribute diffs in HCL before applying!
    ```

=== "GCP State Surgery, Import & Workspaces (`02-gcp-terraform/`)"

    ```bash
    # --- State Surgery on a GCP Service Account ---
    # 6a. Rename google_service_account.gsa -> google_service_account.backend_sa in main.tf
    terraform state mv google_service_account.gsa google_service_account.backend_sa
    terraform plan   # No changes

    # 6b. Forget from state (SA still exists in GCP IAM)
    terraform state rm google_service_account.backend_sa
    # Applying now would fail with Error 409: Service account acme-web-app already exists

    # 6c. Re-import using GCP's full resource URI
    terraform import google_service_account.backend_sa \
      projects/${PROJECT_ID}/serviceAccounts/acme-web-app@${PROJECT_ID}.iam.gserviceaccount.com
    terraform plan   # No changes
    ```

    ```hcl
    # --- Declarative Import & Move Blocks (Terraform 1.5+ / 1.1+, GitOps-friendly) ---
    import {
      to = google_storage_bucket.manual_import
      id = "acme-manual-bucket-${var.project_id}"
    }

    moved {
      from = google_service_account.gsa
      to   = module.backend_sa.google_service_account.this
    }

    # --- Workspace-keyed Resource Naming ---
    resource "google_storage_bucket" "workspace_demo" {
      name                        = "${local.name_prefix}-${terraform.workspace}-demo-${var.project_id}"
      location                    = "US"
      uniform_bucket_level_access = true
      labels                      = local.common_labels
    }
    ```

    ```bash
    # Workspace CLI Lifecycle
    terraform workspace list            # * default
    terraform workspace new dev         # creates & switches to 'dev' state
    terraform workspace select staging  # switches to 'staging' state
    terraform workspace show            # prints active workspace name (verify before apply!)
    ```
