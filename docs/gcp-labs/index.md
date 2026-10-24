# GCP Visual Labs (`02-gcp-terraform/`)

Hands-on Google Cloud Terraform labs with **embedded architecture diagrams** (broken down into focused layer views so every diagram is easy to read inline) plus **interactive HTML inspector dashboards**.

---

## Lab Progression

| # | Lab | Terraform Root | Resources Planned | Core Concepts Practiced |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **[Same-VPC 2-Subnet Connectivity & IAP SSH](01-same-vpc-2-subnets.md)** | `02-gcp-terraform/1-2pc-same-network/` | `7` | Custom VPC, 2 regional subnets (`10.10.0.0/24` & `10.10.1.0/24`), private VMs (`nic0`), IAP SSH tunneling (`35.235.240.0/20`), internal ICMP firewall |
| **2** | **[Cross-VPC Connectivity via VPC Peering](02-vpc-peering.md)** | `02-gcp-terraform/2-2VPCs/` | `10` | 2 isolated VPCs (`vpc-a` & `vpc-b`), bidirectional `google_compute_network_peering` (`a-to-b` & `b-to-a`), automatic control-plane subnet route exchange |
| **3** | **[HA VPN with Cloud Router & Dynamic eBGP](03-ha-vpn-bgp.md)** | `02-gcp-terraform/3-ha-vpn-bgp/` | `25` | `GLOBAL` dynamic routing, Cloud Routers (`ASN 65001` ↔ `65002`), dual-interface HA VPN gateways (`99.99% SLA`), 4 IKEv2 IPsec tunnels, `169.254.x.x/30` link-local eBGP sessions |
| **4** | **[Core GCP Resources, Modules, Storage & IAM](04-core-gcp-resources.md)** | `02-gcp-terraform/core-gcp-resources/` | `16` | Default vs. aliased providers (`us_east`), reusable child modules (`gcp-vm`, `service_account`), `count` (list) vs. `for_each` (set & map), `dynamic` GCS lifecycle rules, GCS backend |

---

## Choosing a GCP Connectivity Pattern (Labs 1 → 2 → 3)

| Question | Lab 1: Same VPC (`1-2pc-same-network`) | Lab 2: VPC Peering (`2-2VPCs`) | Lab 3: HA VPN + eBGP (`3-ha-vpn-bgp`) |
| :--- | :--- | :--- | :--- |
| **Network boundary** | Single VPC (`lab-vpc`) | Two separate VPCs (`vpc-a` ↔ `vpc-b`) | Two separate VPCs or Hybrid On-Prem/Multi-Cloud |
| **How routes are learned** | Built-in VPC local subnet routes | Automatic peering subnet route exchange | Dynamic **eBGP** via Cloud Router over `169.254.x.x/30` |
| **Data plane path** | Andromeda SDN (unencrypted internal fabric) | Andromeda SDN (full line-rate, zero tunnel hops) | Encrypted IPsec IKEv2 tunnels (`~3 Gbps`/tunnel, ECMP) |
| **Transitive routing?** | N/A (same VPC) | **No** (`A ↔ B ↔ C` never routes `A ↔ C`) | **Yes** (with Cloud Router custom route advertisements) |
| **Hourly infrastructure cost** | `$0` (VMs only) | `$0` (VMs only) | `~$0.05/tunnel/hr` × 4 tunnels = `~$0.20/hr` + VMs |
| **Firewall required?** | **Yes** (GCP denies all ingress by default) | **Yes** (Peering adds routes, *not* firewall rules) | **Yes** (BGP adds routes, *not* firewall rules) |
