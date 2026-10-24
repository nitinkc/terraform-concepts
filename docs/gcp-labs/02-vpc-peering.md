# Lab 2 — Cross-VPC Connectivity via VPC Peering

**Code:** `02-gcp-terraform/2-2VPCs/` · **Resources Planned:** `10` · **Interactive View:** [Open Interactive Dashboard :material-open-in-new:](dashboards/2-vpc_peering_architecture.html){ target="_blank" }

---

## 1. Full Topology Overview

When workloads live in **two separate VPCs** (`vpc-a` with `10.10.0.0/24` and `vpc-b` with `10.20.0.0/24`), they are completely isolated by default. **VPC Network Peering** connects both VPCs on Google's Andromeda SDN fabric so subnet routes are exchanged automatically with zero hourly tunnel charges and full line-rate bandwidth.

[![VPC Peering Full Architecture Diagram](../assets/diagrams/gcp-labs/2-vpc-peering-overview.svg)](../assets/diagrams/gcp-labs/2-vpc-peering-overview.svg)

*Click any diagram to open the full-resolution zoomable view, or [launch the interactive HTML inspector](dashboards/2-vpc_peering_architecture.html){ target="_blank" }.*

---

## 2. Visual Breakdown by Layer

### Part A — Zero-Trust IAP SSH & Cross-VPC Firewall Layer

**VPC Peering exchanges routes, NOT firewall rules.** Even after peering is `ACTIVE`, GCP's implied deny-all ingress rule on each VPC blocks packets arriving from the peer VPC until each VPC's firewall explicitly allows the other VPC's subnet CIDR:

[![IAP Proxy and Dual VPC Firewalls](../assets/diagrams/gcp-labs/2-vpc-peering-iap-firewalls.svg)](../assets/diagrams/gcp-labs/2-vpc-peering-iap-firewalls.svg)

- **`vpc-a-allow` (on `vpc-a`):** Allows ingress from `10.20.0.0/24` (peer `subnet-b` in `vpc-b`) and `35.235.240.0/20` (Google IAP TCP forwarding range for SSH).
- **`vpc-b-allow` (on `vpc-b`):** Mirrors the rule on `vpc-b`, allowing ingress from `10.10.0.0/24` (peer `subnet-a` in `vpc-a`) and `35.235.240.0/20`.

```hcl
# Firewall: allow ICMP from the other VPC, SSH via IAP (35.235.240.0/20)
resource "google_compute_firewall" "a_allow" {
  name          = "vpc-a-allow"
  network       = google_compute_network.network-a.name
  source_ranges = ["10.20.0.0/24", "35.235.240.0/20"]
  allow { protocol = "icmp" }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "b_allow" {
  name          = "vpc-b-allow"
  network       = google_compute_network.network-b.name
  source_ranges = ["10.10.0.0/24", "35.235.240.0/20"]
  allow { protocol = "icmp" }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
```

---

### Part B — Bidirectional Peering Bridge (`a-to-b` & `b-to-a`) & Non-Overlapping Subnets

For VPC Peering to become `ACTIVE`, **two** independent `google_compute_network_peering` resources must be created — one initiated from `vpc-a` pointing to `vpc-b`, and one initiated from `vpc-b` pointing to `vpc-a`. If only one side is configured, the peering state remains `INACTIVE` and no routes are exchanged:

[![Bidirectional VPC Peering Bridge and Subnets](../assets/diagrams/gcp-labs/2-vpc-peering-subnets-bridge.svg)](../assets/diagrams/gcp-labs/2-vpc-peering-subnets-bridge.svg)

- **Hard Prerequisite — Non-Overlapping CIDRs:** `subnet-a` (`10.10.0.0/24`) and `subnet-b` (`10.20.0.0/24`) must not overlap with **any** subnet in the peer VPC (even subnets in other regions).
- **Non-Transitive Rule:** VPC Peering is strictly non-transitive. If `VPC-A ↔ VPC-B` and `VPC-B ↔ VPC-C` are peered, `VPC-A` cannot talk to `VPC-C` through `VPC-B`.

```hcl
# Peering must be created from both sides to transition from INACTIVE -> ACTIVE
resource "google_compute_network_peering" "a_to_b" {
  name         = "a-to-b"
  network      = google_compute_network.network-a.self_link
  peer_network = google_compute_network.network-b.self_link
}

resource "google_compute_network_peering" "b_to_a" {
  name         = "b-to-a"
  network      = google_compute_network.network-b.self_link
  peer_network = google_compute_network.network-a.self_link
}
```

---

## 3. Theory to Resource Mapping & Plan Matrix (`10` Resources)

| Networking Concept | Terraform Resource | Planned Instances (`+10` total) |
| :--- | :--- | :--- |
| **Isolated VPC Networks** | `google_compute_network` | `network-a` (`vpc-a`), `network-b` (`vpc-b`) |
| **Non-Overlapping Subnets** | `google_compute_subnetwork` | `subnet-a` (`10.10.0.0/24`), `subnet-b` (`10.20.0.0/24`) |
| **Symmetric VPC Peering** | `google_compute_network_peering` | `a_to_b` (`vpc-a → vpc-b`), `b_to_a` (`vpc-b → vpc-a`) |
| **Ingress Firewalls** | `google_compute_firewall` | `a_allow` (`vpc-a-allow`), `b_allow` (`vpc-b-allow`) |
| **Private Compute VMs** | `google_compute_instance` | `a` (`vm-a`), `b` (`vm-b`) |

---

## 4. Verification Commands

```bash
# 1. Verify both peerings show state: ACTIVE
gcloud compute networks peerings list

# 2. Inspect VPC A's route table to confirm 10.20.0.0/24 was imported via peering
gcloud compute routes list --filter="network:vpc-a"

# 3. Ping vm-b's internal IP from vm-a across the VPC peering link
gcloud compute ssh vm-a --zone us-central1-a --tunnel-through-iap \
  --command "ping -c 4 $(terraform output -raw vm_b_ip)"
```

!!! tip "Cross-VPC Internal DNS Caveat"
    Notice that in Lab 1 (same VPC), `ping vm-b` worked by hostname because GCP's internal DNS (`*.c.<project>.internal`) is scoped to a **single VPC**. Across peered VPCs (`Lab 2`) or VPNs (`Lab 3`), you either ping by **internal IP** (`$(terraform output -raw vm_b_ip)`) or create a Cloud DNS Peering Zone.

---

## 5. Interactive Inspector (Embedded)

??? example "Expand Interactive Component Inspector inline"
    <iframe src="../dashboards/2-vpc_peering_architecture.html" width="100%" height="800" style="border: 1px solid #cbd5e1; border-radius: 12px;" loading="lazy"></iframe>
