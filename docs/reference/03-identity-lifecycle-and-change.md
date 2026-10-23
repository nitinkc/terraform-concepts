# 3 — Resource Identity, Change Behaviour & Lifecycle

**Code:** `01-basics/5-lifecycle/` · `acme-sampleapp-.../cloudsql/infra/cloudsql.tf` · **Quiz:** [Resources, State & Drift](../quiz/02-resources-state-and-drift.md), [GKE](../quiz/05-gke-and-workload-identity.md)

---

## Architect's Points to Keep in Mind

### 1. Address Identity vs. Cloud Resource Name
- Terraform identifies a resource exclusively by its **HCL address** (`google_service_account.gsa`, `module.app["dev"].google_service_account.this`), **never** by the `name` or `account_id` attribute inside the block.
- **Renaming a label in HCL = Destroy + Create.** If you change `resource "google_service_account" "gsa"` to `"backend_sa"`, Terraform sees `gsa` removed (`- destroy`) and `backend_sa` added (`+ create`).
- **Two ways to rename without destroying:**
  1. **Declarative (`moved` block, Terraform 1.1+ — preferred in GitOps/teams):** committed to Git so every teammate's and CI runner's next plan automatically migrates the state address.
  2. **Imperative (`terraform state mv`):** mutates state directly; fine for one-off local fixes.

```hcl
moved {
  from = google_service_account.gsa
  to   = google_service_account.backend_sa
}
```

### 2. In-Place Update (`~`) vs. Force Replacement (`-/+`)
- **In-place update (`~`):** The underlying cloud API allows mutating the field (e.g., `display_name` on a GCP service account or `labels` on a bucket).
- **Force replacement (`-/+` `# forces replacement`):** The cloud API treats the field as immutable after creation (e.g., `account_id` on a service account, `name`/`location` on a GCS bucket, or `machine_type` on a `google_container_node_pool`).
  - *Operational impact:* Changing a GKE node pool's `machine_type` destroys the old node pool and provisions a new one, rescheduling all running pods.
- **Deliberate replacement without HCL changes:**
  ```bash
  terraform apply -replace=google_compute_instance.vm
  ```
  (Replaces the deprecated `terraform taint` command.)

### 3. `lifecycle` Meta-Arguments (Core-Interpreted Overrides)
Every resource supports a `lifecycle {}` block evaluated by Terraform Core:

| Meta-Argument | Effect | Architect's Caveat |
|---|---|---|
| `create_before_destroy = true` | Provisions replacement *before* destroying the old instance | **Fails if the resource has a fixed/unique name** in the cloud API (e.g., fixed `account_id` or bucket `name`) unless paired with `name_prefix` or a random suffix. Also propagates upward through dependencies. |
| `prevent_destroy = true` | Hard-fails any plan that would destroy the resource | **Blocks Force-New replacements too**, not just `terraform destroy`. Removing the `lifecycle` block (or the whole resource block from HCL) bypasses it, because the rule only exists while the block is in code. |
| `ignore_changes = [attr]` | Ignores live drift on specified attributes (or `all`) | Takes **bare attribute references** (e.g., `[labels, settings[0].disk_size]`), *not* strings. Naming a non-existent attribute (like `[tags]` on `local_file`) fails validation immediately. |
| `replace_triggered_by = [...]` | Replaces this resource whenever the referenced resource/attribute changes | Useful when a downstream resource must cycle whenever an upstream config/secret resource is replaced. |

### 4. When to Use `ignore_changes` (and When Not To)
- **Legitimate use:** Split ownership where an external controller or automation mutates a field at runtime — e.g., a GKE cluster autoscaler changing `node_count`, an external admission controller stamping `annotations` or `labels`, or an attribute populated by a volatile function (`timestamp()`).
- **Anti-pattern:** Using `ignore_changes` to silence a plan diff you haven't diagnosed yet.

---

## Code Reference

=== "Local (`01-basics/5-lifecycle`)"

    ```hcl
    resource "local_file" "pet" {
      filename        = "/tmp/hello.txt"
      content         = "Hello! Let the learning commence...."
      file_permission = "0700"

      lifecycle {
        create_before_destroy = true
        prevent_destroy       = false

        # NOTE: In 01-basics/5-lifecycle, `tags` was placed here as a deliberate defect.
        # `local_file` has no `tags` attribute; valid attributes are `content` or `file_permission`.
        ignore_changes = [
          content,
        ]
      }
    }
    ```

    ```bash
    terraform init && terraform apply -auto-approve
    echo "manual out-of-band edit" > /tmp/hello.txt
    terraform plan   # "No changes" — drift on `content` is ignored
    ```

=== "GCP Production Guards (`02-gcp-terraform/` & Sandbox)"

    ```hcl
    # 1. Protect stateful Cloud SQL instance from accidental destruction or Force-New replacement
    resource "google_sql_database_instance" "main" {
      name             = "acme-pg-instance"
      database_version = "POSTGRES_15"
      region           = var.region

      settings {
        tier      = "db-f1-micro"
        disk_size = 20
      }

      lifecycle {
        prevent_destroy = true
        ignore_changes  = [settings[0].disk_size] # allow storage auto-increase without drift
      }
    }

    # 2. Ignore external label automation on GCS bucket
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
