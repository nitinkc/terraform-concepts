# 10 — Production Architecture: Multi-Repo, GKE, Networking & CI/CD

**Code:** `02-gcp-terraform/1-2pc-same-network/` · `2-2VPCs/` · `../../acme-sampleapp-multirepo` · **Quiz:** [Multi-Repo & Consul](../quiz/04-multirepo-and-consul.md), [GKE & WI](../quiz/05-gke-and-workload-identity.md), [Debugging](../quiz/06-debugging-and-verification.md)

---

## Architect's Points to Keep in Mind

### 1. Root Boundaries, Blast Radius & File Conventions
- **A Root is a Blast Radius:** One root directory = one state file = one lock = one failure domain.
- **When to Split a Root:**
  1. **Lifecycle cadence:** Stateful, slow-changing infra (VPC, GKE, Cloud SQL) must not share a state file with high-churn application deployments (Helm releases).
  2. **Team ownership & least privilege:** App teams shouldn't hold IAM permissions to mutate core networking or databases.
  3. **Plan/refresh latency:** Hundreds of resources in one state file slow down every `plan` and hit API rate limits.
- **Standard File Layout:** Terraform merges all `.tf` files in a directory alphabetically (`versions.tf`, `providers.tf`, `backend.tf`, `variables.tf`, `locals.tf`, `data.tf`, `main.tf`, `outputs.tf`, plus domain splits like `iam.tf`, `rbac.tf`, `cloudsql.tf`). Always keep all `output` blocks in `outputs.tf` and all `variable` blocks in `variables.tf` so the root's schema is scannable without `grep`.

### 2. Cross-Config Composition: Shared KV (Consul) vs. `terraform_remote_state`
When Root B needs values created by Root A (e.g., GKE endpoint, VPC subnet, GSA email):

| Dimension | `data "terraform_remote_state"` | Shared KV Contract (`consul_keys` / SSM) |
|---|---|---|
| **Extra Infrastructure** | None (reads producer's GCS state bucket directly) | Requires highly available KV store with ACLs |
| **Security & Isolation** | **Weak:** Consumer requires read access to Producer's **entire** state file, including all plaintext secrets | **Strong:** Producer explicitly publishes only non-sensitive contract fields |
| **Coupling** | Coupled to Producer's backend path and `outputs.tf` | Coupled to an explicit JSON key schema |

- **Four Cross-Repo Contract Rules (Proven in Acme Sandbox):**
  1. **Apply & Destroy Ordering:** Apply upstream producers first (`sample-program` → `infrastructure`/`cloudsql` → `backend` → `frontend`); destroy in **strict reverse order**.
  2. **Who Owns a Cross-Repo IAM Grant?** If Repo A runs before Repo B, Repo A cannot reference a Service Account created by Repo B (circular dependency). **Place the IAM binding in whichever repo already has all required data available in the forward apply sequence** (e.g., `backend/infra` grants its own GSA access to the SSO secret published by `infrastructure/infra`).
  3. **Never Publish Raw Secrets to KV:** Publish the **Secret Manager resource ID** (`google_secret_manager_secret.sso.id`), and let the consumer grant/read it with its own IAM identity.
  4. **Stale KV Data After Destroy:** `terraform destroy` deletes cloud resources, *not* orphaned keys in external KV stores if a destroy script skips a step. Always clean KV contracts on teardown and verify live cloud resources independently.

### 3. GCP Networking: Subnets, VPC Peering & IAP TCP Forwarding
- **VPC Regional Subnets:** In GCP, VPCs are global and subnets are regional. Two VMs in different subnets of the **same VPC** can communicate over internal IPs as long as an ingress `google_compute_firewall` rule allows traffic from the peer subnet's CIDR.
- **Connecting Two Separate VPCs:**
  - **VPC Peering (`google_compute_network_peering`):** Bi-directional (requires peering blocks on *both* VPCs: A→B and B→A), non-transitive, exchanges subnet routes automatically, no hourly tunnel charge. Still requires firewall rules on each VPC allowing the peer subnet CIDR.
  - **HA VPN:** Uses Cloud Routers + BGP sessions + encrypted IPsec tunnels; teaches dynamic routing and supports transitive/hybrid topologies, but bills hourly per tunnel.
- **SSH to Private VMs via Identity-Aware Proxy (IAP):**
  - VMs without external IPs cannot be reached directly from a laptop.
  - Running `gcloud compute ssh vm-a --tunnel-through-iap` proxies TCP port 22 through Google's IAP servers (`35.235.240.0/20`).
  - **Mandatory Firewall Rule:** GCP denies all ingress by default; you **must** allow TCP port `22` from `source_ranges = ["35.235.240.0/20"]` (and hold `roles/iap.tunnelResourceAccessor`), or SSH fails with error `4033`/`4003`.

### 4. GKE & Workload Identity Production Gotchas (High-Yield Interview Topics)
1. **Never Use the Default Compute Engine Service Account:**
   - It may not exist in newer/hardened GCP projects (`Failed precondition: verify if principal exists`), and when it does exist, it carries broad `roles/editor` permissions.
   - Always create a dedicated, least-privilege node GSA granted `roles/logging.logWriter`, `roles/monitoring.metricWriter`, `roles/monitoring.viewer`, and `roles/artifactregistry.reader`.
2. **The `remove_default_node_pool = true` Transient Pool Trap:**
   - Separating `google_container_cluster` and `google_container_node_pool` lets you resize/upgrade node pools independently without recreating the cluster.
   - **Gotcha:** Even with `remove_default_node_pool = true`, GKE briefly creates a transient initial node pool during cluster bootstrap and deletes it immediately after. That transient pool uses `node_config` on `google_container_cluster` itself! You **must** set `node_config { service_account = ... }` on **both** `google_container_cluster` and `google_container_node_pool`.
3. **Workload Identity (Linking K8s SA ↔ GCP IAM SA):**
   - A Kubernetes `ServiceAccount` (KSA) and a GCP `google_service_account` (GSA) are two completely separate identities in two separate systems. Name matching does nothing.
   - **Four pieces required for a pod to authenticate as a GSA:**
     1. **Cluster level:** `workload_identity_config { workload_pool = "${var.project_id}.svc.id.goog" }` on `google_container_cluster`.
     2. **Node pool level:** `workload_metadata_config { mode = "GKE_METADATA" }` on `google_container_node_pool` (runs the GKE metadata server DaemonSet on nodes).
     3. **GCP IAM binding:** Grant `roles/iam.workloadIdentityUser` on the GSA to member `"serviceAccount:${var.project_id}.svc.id.goog[${namespace}/${ksa_name}]"`.
     4. **Kubernetes SA annotation:** Stamp `iam.gke.io/gcp-service-account: <gsa-email>` on the Kubernetes `ServiceAccount`.
4. **GCP IAM vs. Kubernetes RBAC (`kubectl` Forbidden despite `roles/owner`):**
   - GCP IAM controls access to the GKE Cloud API; Kubernetes RBAC controls actions inside the cluster API server.
   - If `kubectl get pods` returns `Forbidden` despite having `roles/owner`: (a) check for a stale `kubeconfig` authenticated as a different `gcloud` account (`gcloud container clusters get-credentials` + `kubectl auth can-i`), and (b) verify `ClusterRoleBinding`/`RoleBinding` exists for your identity.
5. **Node Capacity vs. Allocatable, Spot Readiness & Shared-Core Machine Types:**
   - `Allocatable` CPU/memory is significantly lower than `Capacity` because GKE reserves resources for the OS/kubelet and system DaemonSets (`kube-proxy`, logging, `gke-metadata-server`).
   - **Spot Node Startup vs. Configuration Drift:** When a GKE node pool reports `RUNNING` in GCP but `kubectl get nodes` shows zero `Ready` nodes, check node pool provisioning/Spot capacity state before assuming Terraform drift — Spot VMs can take extra time to allocate and register with the control plane.
   - **Sizing Trap:** `e2-micro`, `e2-small`, and `e2-medium` are all **shared-core** VMs with the same 2-vCPU ceiling — stepping from `e2-small` to `e2-medium` increases memory (2 GiB → 4 GiB) but adds **zero allocatable vCPU**. Move to `e2-standard-2` for dedicated vCPUs.
   - **Image Architecture:** Standard x86 GKE nodes require `linux/amd64` container images (`docker build --platform linux/amd64`); pushing an Apple Silicon `arm64`-only manifest fails pod startup with `no match for platform in manifest`.
6. **Cloud SQL Auth Proxy Sidecar & `shell_script` In-Database Grant Bridge:**
   - **Passwordless IAM Database Auth:** Set `cloudsql.iam_authentication = "on"` on `google_sql_database_instance` and create a `google_sql_user` with `type = "CLOUD_IAM_SERVICE_ACCOUNT"` and `name = trimsuffix(google_service_account.app.email, ".gserviceaccount.com")` (Postgres IAM users must omit the `.gserviceaccount.com` suffix). No DB password ever exists in `terraform.tfstate`.
   - **Custom CRUD Lifecycle Bridge (`scottwinkler/shell`):** Terraform's `google_sql_user` creates the database principal, but cannot execute SQL `GRANT` statements inside a private-IP database. `backend/infra/iam.tf` uses a `shell_script` resource with `create`/`read`/`delete` lifecycle commands to mint an OIDC ID token and call the producer's grant/revoke Cloud Functions, wired into `helm_release` via `depends_on` so pods never start before schema grants complete.

### 5. GitOps & CI/CD Execution Security
- **Why CI/CD:** Developers never hold state bucket read access or production GCP credentials on laptops. CI runs `terraform plan` on PRs using a read-only identity and `terraform apply` on protected `main` using a write identity via **Workload Identity Federation (OIDC → GCP STS, no JSON keys)**.
- **The PR Arbitrary Code Execution Attack Surface:**
  - `terraform plan` executes arbitrary code defined on the PR branch (`external` data sources, malicious module sources, or `local-exec` if `apply` runs).
  - An attacker can exfiltrate plaintext secrets from `terraform.tfstate` via network (`curl`) or print them to CI stdout.
  - **Why CI Secret Masking Is Not Enough:** CI log masking uses literal string matching (`***`) and is trivially bypassed by encoding (`echo $SECRET | base64`).
  - **Primary Defense-in-Depth Control:** **Mandatory human PR review and approval before triggering any CI `plan` job**, combined with isolated runners (restricted egress), least-privilege `plan` SAs, and branch protection conditions enforced in the GCP WIF `attribute_condition` / `principalSet`.

### 6. Hypothesis-Ordered Debugging & Independent Verification
- **Order hypotheses from cheapest/fastest to falsify before reading all code:**
  1. Local process/environment & binary readiness (`command -v consul`, `pgrep consul`, `consul members`, `consul kv get`, `gcloud auth list`). Always health-check provider-backed local dependencies before running `terraform plan`/`apply`.
  2. Active workspace & non-empty state ledger (`terraform workspace show`, `terraform state list` — never trust the mere existence of a `terraform.tfstate` file on disk, as an empty state file with `"resources": []` still passes file-existence checks).
  3. Code/contract inspection (e.g., catching a hardcoded `/default` Consul path next to a parameterized `/${local.env_key}` path).
- **Never trust a green `terraform apply` as proof of system health:** `apply` succeeding only proves the API accepted the request (a `helm_release` or GKE cluster can report `RUNNING` while its node pool is missing or pods are `CrashLoopBackOff`). Always verify independently with `kubectl get nodes`, `kubectl get pods`, `kubectl get sa -o jsonpath='{.metadata.annotations}'`, and `gcloud`.

---

## Code Reference

=== "GCP VPC, Peering & IAP SSH (`02-gcp-terraform/1-2pc-…` & `2-2VPCs`)"

    ```hcl
    # Allow SSH to private VMs (no public IP) via Google Identity-Aware Proxy (IAP)
    resource "google_compute_firewall" "iap_ssh" {
      name          = "allow-iap-ssh"
      network       = google_compute_network.vpc_a.name
      source_ranges = ["35.235.240.0/20"] # Google IAP TCP forwarding range
      allow {
        protocol = "tcp"
        ports    = ["22"]
      }
    }

    # Bi-directional VPC Peering (both directions required for route exchange)
    resource "google_compute_network_peering" "a_to_b" {
      name         = "peer-a-to-b"
      network      = google_compute_network.vpc_a.self_link
      peer_network = google_compute_network.vpc_b.self_link
    }

    resource "google_compute_network_peering" "b_to_a" {
      name         = "peer-b-to-a"
      network      = google_compute_network.vpc_b.self_link
      peer_network = google_compute_network.vpc_a.self_link
    }
    ```

    ```bash
    # Test private VM connectivity through IAP tunnel
    gcloud compute ssh vm-a --zone us-central1-a --tunnel-through-iap --command "ping -c 4 10.20.0.2"
    ```

=== "GKE Dedicated Node SA & Workload Identity (`acme-sampleapp-.../`)"

    ```hcl
    # 1. Dedicated least-privilege GKE Node Service Account (sample-program/infra/modules/gke/main.tf)
    resource "google_service_account" "node" {
      project    = var.project_id
      account_id = "${var.name}-node-sa"
    }

    resource "google_container_cluster" "main" {
      name                     = var.name
      location                 = var.zone
      remove_default_node_pool = true
      initial_node_count       = 1

      # CRITICAL: Transient initial node pool still reads `node_config` on the cluster resource!
      node_config {
        service_account = google_service_account.node.email
        oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
      }

      workload_identity_config {
        workload_pool = "${var.project_id}.svc.id.goog" # 1/4: Enable WI on cluster
      }
    }

    resource "google_container_node_pool" "primary" {
      name       = "${var.name}-pool"
      location   = var.zone
      cluster    = google_container_cluster.main.name
      node_count = var.node_count

      node_config {
        machine_type    = var.machine_type # e2-standard-2 for real vCPU headroom
        spot            = var.spot
        service_account = google_service_account.node.email
        oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

        workload_metadata_config {
          mode = "GKE_METADATA" # 2/4: Enable GKE metadata server on node pool
        }
      }
    }

    # 2. Workload Identity Binding: GSA <-> KSA (backend/infra/iam.tf & Helm chart)
    resource "google_service_account_iam_member" "workload_identity" {
      service_account_id = google_service_account.backend.name
      role               = "roles/iam.workloadIdentityUser"
      # 3/4: Bind K8s namespace + KSA name to GCP Service Account
      member             = "serviceAccount:${local.program_gcp.project}.svc.id.goog[${kubernetes_namespace_v1.backend.metadata[0].name}/${local.ksa_name}]"
    }
    # 4/4: K8s ServiceAccount carries annotation `iam.gke.io/gcp-service-account: <gsa-email>`
    ```

=== "Cross-Repo Consul Contract (Publish & Consume)"

    ```hcl
    # Producer (sample-program/infra/main.tf) — Publishes explicit JSON contract
    resource "consul_keys" "publish_outputs" {
      key {
        path  = "acme-sampleapp/sample-program/default"
        value = jsonencode({
          outputs = {
            gcp = {
              us_central1 = {
                for k, cluster in module.gke : k => {
                  project = var.project_id
                  gke     = {
                    name                   = cluster.name
                    host                   = cluster.endpoint
                    cluster_ca_certificate = cluster.ca_certificate
                  }
                }
              }
            }
          }
        })
      }
    }

    # Consumer (backend/infra/main.tf) — Parameterized environment lookup
    data "consul_keys" "remote_outputs" {
      key {
        name = "program"
        path = "acme-sampleapp/sample-program/default"
      }
      key {
        name = "infrastructure"
        path = "acme-sampleapp/infrastructure/${local.infra_env_key}" # Parameterized, never hardcoded!
      }
    }
    ```
