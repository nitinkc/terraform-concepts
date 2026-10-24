# Lab 1 — Same-VPC Two-Subnet Connectivity & IAP SSH

**Code:** `02-gcp-terraform/1-2pc-same-network/` · **Resources Planned:** `7` · **Interactive View:** [Open Interactive Dashboard :material-open-in-new:](dashboards/1-2subnet-connectivity.html){ target="_blank" }

---

## 1. Full Topology Overview

Two regional subnets (`subnet-a: 10.10.0.0/24` and `subnet-b: 10.10.1.0/24`) inside a single custom-mode VPC (`lab-vpc`). Because GCP automatically creates intra-VPC subnet routes, `vm-a` and `vm-b` can reach each other as soon as an ingress firewall rule permits ICMP.

[![Same-VPC 2-Subnet Full Architecture Diagram](../assets/diagrams/gcp-labs/1-2subnet-overview.svg)](../assets/diagrams/gcp-labs/1-2subnet-overview.svg)

*Click any diagram to open the full-resolution zoomable view, or [launch the interactive HTML inspector](dashboards/1-2subnet-connectivity.html){ target="_blank" }.*

---

## 2. Visual Breakdown by Layer

### Part A — Security & Firewall Layer (IAP TCP Forwarding + Internal ICMP)

GCP's implied firewall rules **allow all egress** (`0.0.0.0/0`) and **deny all ingress** (`0.0.0.0/0` at priority `65535`). Even within the same VPC, two VMs cannot ping or SSH to each other until explicit ingress firewall rules are created:

[![Firewall and IAP Ingress Layer](../assets/diagrams/gcp-labs/1-2subnet-firewalls-iap.svg)](../assets/diagrams/gcp-labs/1-2subnet-firewalls-iap.svg)

- **`allow-iap-ssh` (`35.235.240.0/20` → `tcp:22`):** Neither VM has a public IP address. When you run `gcloud compute ssh vm-a --tunnel-through-iap`, your laptop connects to Google's Identity-Aware Proxy (IAP), which forwards TCP port `22` to the VM from Google's reserved range **`35.235.240.0/20`**. Without this source range allowed on TCP `22`, IAP SSH fails with error `4033`/`4003`.
- **`allow-internal-icmp` (`10.10.0.0/16` → `icmp`):** Allows `ping` traffic across the `/16` supernet covering both `10.10.0.0/24` (`subnet-a`) and `10.10.1.0/24` (`subnet-b`).

```hcl
# Allow ICMP between subnets, and SSH via IAP (Identity-Aware Proxy) only
resource "google_compute_firewall" "internal_icmp" {
  name          = "allow-internal-icmp"
  network       = google_compute_network.main.name
  source_ranges = ["10.10.0.0/16"]
  allow { protocol = "icmp" }
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "allow-iap-ssh"
  network       = google_compute_network.main.name
  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
```

---

### Part B — Regional Subnets & Compute Instances (`nic0`)

In Google Cloud and Terraform, the `network_interface` block on `google_compute_instance` represents the Virtual Network Interface Card (**vNIC** / `nic0`) of the VM. Notice there is **no `access_config {}` block**, which keeps both VMs private-only (no external IP):

[![Regional Subnets and VMs Layer](../assets/diagrams/gcp-labs/1-2subnet-subnets-vms.svg)](../assets/diagrams/gcp-labs/1-2subnet-subnets-vms.svg)

```hcl
resource "google_compute_network" "main" {
  name                    = "lab-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "a" {
  name          = "subnet-a"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = "10.10.0.0/24"
}

resource "google_compute_instance" "a" {
  name         = "vm-a"
  zone         = var.zone
  machine_type = "e2-micro"
  boot_disk {
    initialize_params { image = "debian-cloud/debian-12" }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.a.id
  }
}
```

---

## 3. Execution Plan Matrix (`7` Resources)

| Action | Resource Type | Identifier | Primary Configuration & Scope |
| :--- | :--- | :--- | :--- |
| `+ CREATE` | `google_compute_network` | **`main` (`lab-vpc`)** | Custom mode (`auto_create_subnetworks = false`) |
| `+ CREATE` | `google_compute_subnetwork` | **`a` (`subnet-a`)** | CIDR: `10.10.0.0/24` · Region: `us-central1` |
| `+ CREATE` | `google_compute_subnetwork` | **`b` (`subnet-b`)** | CIDR: `10.10.1.0/24` · Region: `us-central1` |
| `+ CREATE` | `google_compute_instance` | **`a` (`vm-a`)** | `e2-micro` · Debian 12 · `subnet-a` · `us-central1-a` (no public IP) |
| `+ CREATE` | `google_compute_instance` | **`b` (`vm-b`)** | `e2-micro` · Debian 12 · `subnet-b` · `us-central1-a` (no public IP) |
| `+ CREATE` | `google_compute_firewall` | **`iap_ssh` (`allow-iap-ssh`)** | Ingress `tcp:22` · Source: `35.235.240.0/20` (IAP) |
| `+ CREATE` | `google_compute_firewall` | **`internal_icmp` (`allow-internal-icmp`)** | Ingress `icmp` · Source: `10.10.0.0/16` |

---

## 4. Verification & IAP SSH Commands

```bash
# Prerequisites (if not already enabled in the project)
gcloud auth login
gcloud config set project my-devops-journey-502420
gcloud services enable compute.googleapis.com iap.googleapis.com

# Interactive SSH into private vm-a via IAP TCP forwarding
gcloud compute ssh vm-a --zone us-central1-a --tunnel-through-iap

# Non-interactive ping from vm-a (10.10.0.x) -> vm-b (10.10.1.x) using internal DNS name
gcloud compute ssh vm-a --zone us-central1-a --tunnel-through-iap \
  --command "ping -c 4 vm-b"

# Non-interactive ping from vm-b -> vm-a
gcloud compute ssh vm-b --zone us-central1-a --tunnel-through-iap \
  --command "ping -c 4 vm-a"
```

!!! info "IAM Requirement for IAP Tunneling"
    If you are not the project `Owner`, your user principal requires the **IAP-secured Tunnel User** role (`roles/iap.tunnelResourceAccessor`) and Compute instance SSH access (`roles/compute.osLogin` or `roles/compute.instanceAdmin.v1`).

---

## 5. Interactive Inspector (Embedded)

??? example "Expand Interactive Component Inspector inline"
    <iframe src="../dashboards/1-2subnet-connectivity.html" width="100%" height="780" style="border: 1px solid #cbd5e1; border-radius: 12px;" loading="lazy"></iframe>
