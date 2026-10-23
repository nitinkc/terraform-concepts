# 4 — Dependencies & the Execution Graph

**Code:** `01-basics/3-resource-attribute-reference/` · `01-basics/4-dependencies/` · `02-gcp-terraform/z-core-gcp-resources/network.tf`

---

## Architect's Points to Keep in Mind

### 1. HCL is a Directed Acyclic Graph (DAG), Not Top-to-Bottom Code
- Terraform concatenates every `.tf` file in a directory and constructs a **dependency graph** from resource references.
- **File names and block order have zero effect on execution order.** Independent resources are provisioned in parallel (default parallelism = 10); dependent resources run sequentially.
- **Destroy order is the exact reverse of create order.** If `subnet` references `vpc`, Terraform creates `vpc` → `subnet` and destroys `subnet` → `vpc`.

### 2. Implicit Dependencies vs. `depends_on` (Explicit)
- **Implicit dependency:** Referencing one resource's attribute inside another (e.g., `network = google_compute_network.vpc.id` or `member = "serviceAccount:${google_service_account.gsa.email}"`) **is** the dependency declaration. There is no flag to enable it.
  - *Note:* In `01-basics/`, `3-resource-attribute-reference/main.tf` and `4-dependencies/implicit/main.tf` are byte-identical on purpose — an attribute reference already creates the graph edge.
- **Explicit dependency (`depends_on = [...]`):** If Resource B already interpolates an attribute of Resource A, adding `depends_on = [A]` is **100% redundant** (producing the exact same `terraform graph`).
- **When `depends_on` is genuinely required** (real-world runtime dependencies invisible to HCL):
  1. **IAM Propagation:** A workload (`helm_release`, `google_compute_instance`, or GKE cluster) needs an IAM binding (`google_project_iam_member`, `google_service_account_iam_member`) to exist before it starts, even though it never interpolates an attribute of the IAM binding block.
  2. **API Enablement:** A resource requires `google_project_service.api` to finish enabling an API before calling it.
  3. **Side-effect / Bridge Ordering (The `shell_script` / `helm_release` Race Condition):** In `backend/infra`, `helm_release.acme_sampleapp_backend` does not interpolate any attribute from `google_project_iam_member.backend_sql_access`, `google_service_account_iam_member.workload_identity`, or `shell_script.backend_sa_sql_access` (which invokes a Cloud Function to grant in-database Postgres roles). Without explicit `depends_on` on all three, Terraform deploys the Helm chart in parallel with the IAM/DB grants, and the pod immediately enters `CrashLoopBackOff` on startup because its Service Account cannot yet authenticate or read its schema.
- **Caution with `depends_on` on Modules or Data Sources:** Adding `depends_on` to a `data` block forces Terraform to defer reading the data source until the `apply` phase whenever any depended-on resource has planned changes, turning downstream attributes into `(known after apply)`.

### 3. Plan-Time Unknowns (`(known after apply)`)
- Computed attributes (like `id`, `self_link`, or `email`) do not exist until the cloud API creates the resource. During `plan`, Terraform marks them `(known after apply)`.
- **The DAG Cardinal Rule:** **`count` and `for_each` keys/lengths cannot depend on values that are unknown at plan time.**
  - Why? Terraform Core must build the full graph of resource instances *before* executing `apply`.
  - If `for_each` depends on a computed attribute of a not-yet-created resource, `plan` fails with:
    `The "for_each" value depends on resource attributes that cannot be determined until apply`.
  - **Architectural Fix:** Always drive `for_each` keys and `count` lengths from static inputs (`var.*` or `local.*` derived from variables), never from computed resource attributes. (If unavoidable in an emergency, `-target` the upstream resource first, then refactor the keys.)

---

## Code Reference

=== "Local (`01-basics/3-…` & `4-dependencies`)"

    ```hcl
    resource "random_pet" "my_pet" {
      prefix    = var.prefix
      separator = var.separator
      length    = var.name_length
    }

    resource "local_file" "pet" {
      filename = var.fileName
      # Implicit dependency: pet.id is (known after apply) until random_pet is created
      content  = "Here is the Random Pet ${random_pet.my_pet.id}"

      # Redundant here because `content` already references `random_pet.my_pet.id`
      depends_on = [
        random_pet.my_pet
      ]
    }
    ```

    ```bash
    # Verify that replacing the upstream dependency cascades to downstream consumers
    terraform apply -replace=random_pet.my_pet

    # Render the DAG (requires Graphviz `dot`)
    terraform graph | dot -Tsvg > graph.svg
    ```

=== "GCP Implicit vs. Explicit (`02-gcp-terraform/` & Sandbox)"

    ```hcl
    # 1. Implicit dependency: VPC -> Subnet (via .id) & SA -> IAM Member (via .email)
    resource "google_compute_network" "vpc" {
      name                    = "fde-training-vpc"
      auto_create_subnetworks = false
    }

    resource "google_compute_subnetwork" "subnet" {
      name          = "fde-training-subnet"
      ip_cidr_range = "10.0.1.0/24"
      region        = "us-central1"
      network       = google_compute_network.vpc.id # Implicit edge: VPC created first
    }

    resource "google_service_account" "gsa" {
      account_id   = "${local.name_prefix}-web-app"
      display_name = "My Test App"
    }

    resource "google_project_iam_member" "sa_sql_client" {
      project = var.project_id
      role    = "roles/cloudsql.client"
      member  = "serviceAccount:${google_service_account.gsa.email}" # Implicit edge: SA created first
    }

    # 2. Legitimate explicit `depends_on`: API enablement & IAM before workload
    resource "google_project_service" "secretmanager" {
      service            = "secretmanager.googleapis.com"
      disable_on_destroy = false
    }

    resource "google_secret_manager_secret" "sso" {
      secret_id  = "sso-config"
      replication { auto {} }
      depends_on = [google_project_service.secretmanager] # Hidden runtime edge
    }
    ```
