# 2 — Resources, State Mechanics & Backends

**Code:** `01-basics/1-create-local-file/` · `02-gcp-terraform/z-core-gcp-resources/backend.tf` · **Quiz:** [Resources, State & Drift](../quiz/02-resources-state-and-drift.md)

---

## Architect's Points to Keep in Mind

### 1. Resource Block Anatomy & Ownership
```hcl
resource "<provider_type>" "<local_name>" { ... }
```

- **First label (`google_service_account`)**: fixed by the provider plugin.
- **Second label (`gsa`)**: local identifier chosen by you, unique per resource type within the module.
- Together, `google_service_account.gsa` is the **resource address** — the primary key in `terraform.tfstate`.

### 2. Why `terraform.tfstate` Must Exist

1. **Identity Mapping (Load-Bearing):** Cloud APIs have no native concept of "this bucket belongs to this `.tf` file." State maps HCL addresses (`google_service_account.gsa`) to real cloud IDs (`projects/.../serviceAccounts/...`).
2. **Performance:** Caching attributes avoids querying every cloud resource when unnecessary and prevents API rate-limiting at scale.
3. **Dependency & Metadata:** Stores resource dependency edges (necessary for correct destroy ordering even after a block is deleted from HCL) and provider-computed values.

### 3. `terraform apply` is Non-Atomic (Per-Resource Commit)

- **Interview Highlight:** Terraform `apply` is **not transactional**. There is no automatic rollback if resource #7 of 7 fails.
- As each individual resource finishes creation, Terraform immediately records it in state.
- If a 7-resource apply fails on #7 (e.g., a transient network error or unreachable Consul endpoint), the first 6 resources are live and durably tracked in state. Re-running `terraform plan` shows only `1 to add` (idempotent convergence).

### 4. Missing Resource vs. Missing State (Provider-Specific Failure Modes)

- **Delete the real resource, keep state:** During `plan`, the refresh phase queries the provider, sees the resource is gone, and proposes **recreating** it (`+ create`).
- **Delete the state file, keep the real resource:** Terraform has complete amnesia. It does *not* scan the cloud to rediscover orphans; it plans to create everything fresh.
    - **File-based providers (`local_file`):** silently overwrite/clobber the existing file on disk.
    - **Cloud APIs (`google_service_account`, `google_storage_bucket`):** reject duplicate identifiers with `Error 409: AlreadyExists`. Recovery requires `terraform import`.
- **Empty State File Trap:** A `terraform.tfstate` file existing on disk does not prove resources are tracked — an initialized or destroyed root still has a valid JSON state file with `"resources": []`. Always check `terraform state list`.

### 5. Remote Backends (GCS) & The Chicken-and-Egg Problem
Moving state from local disk to a remote backend (`backend "gcs"`) provides:

- **State Locking:** prevents concurrent `apply` runs from corrupting state.
- **Encryption at Rest:** Google-managed encryption or CMEK (local state is always unencrypted plaintext JSON).
- **Versioning & Recovery:** GCS object versioning allows rolling back accidental state corruption.

**Two Backend Constraints to Remember:**

1. **Bootstrap Chicken-and-Egg:** `terraform init` connects to the backend *before* parsing any `resource` blocks. Therefore, a Terraform configuration cannot create the GCS bucket that stores its own state. Create the state bucket out-of-band (`gcloud storage buckets create` / `gsutil mb`) or via a dedicated `bootstrap` root.
2. **No Variables in `backend {}`:** Backend blocks cannot interpolate `var.*` or `local.*`. Use a **partial backend configuration** (`backend "gcs" {}`) and pass `-backend-config="bucket=..." -backend-config="prefix=..."` during `terraform init`.
    - *Gotcha:* Omitting `-backend-config` on a partial `gcs` backend does not error with "missing bucket argument" — Terraform queries GCS with an empty bucket name and returns `storage: bucket doesn't exist ... 404`.

### 6. The `plan` Read-Access Security Constraint

- Running `terraform plan` **requires read access** to the state file.
- Because state stores every attribute in **plaintext** (including secrets marked `sensitive = true`), **anyone who has IAM permissions to run `terraform plan` against a state file can read every secret inside that state (`terraform state pull`).**
- This is the primary architectural reason to move `plan`/`apply` off developer laptops and into isolated CI/CD runners.

---

## Code Reference

=== "Local (`01-basics/1-create-local-file`)"

    ```hcl
    resource "local_file" "pet" {
      filename        = "/tmp/hello.txt"
      content         = "Hello! Let the terraform learning commence...."
      file_permission = "0700"
    }
    ```

    ```bash
    # Experiment 1: Drift recovery (state intact, file deleted)
    terraform init && terraform apply -auto-approve
    rm /tmp/hello.txt
    terraform plan   # Refresh detects missing file -> plans 1 to add

    # Experiment 2: State amnesia (file intact, state deleted)
    rm terraform.tfstate*
    terraform plan   # No memory of file -> plans 1 to add (silently clobbers on apply)
    ```

=== "GCP Partial Backend (`02-gcp-terraform/z-core-gcp-resources`)"

    ```hcl
    # backend.tf — Partial configuration (no hardcoded bucket names in Git)
    terraform {
      backend "gcs" {}
    }

    # resources.tf — First managed cloud resource
    resource "google_service_account" "gsa" {
      account_id   = "acme-web-app"
      display_name = "My Test App"
    }
    ```

    ```bash
    # 1. Bootstrap bucket out-of-band (globally unique name, versioning enabled)
    gsutil mb -l us-central1 gs://YOUR-UNIQUE-BUCKET-tfstate
    gsutil versioning set on gs://YOUR-UNIQUE-BUCKET-tfstate

    # 2. Initialize & migrate local state to GCS
    terraform init \
      -backend-config="bucket=YOUR-UNIQUE-BUCKET-tfstate" \
      -backend-config="prefix=core-gcp-resources/state"

    # 3. Verify state ledger
    terraform state list
    terraform state show google_service_account.gsa
    ```
