

# Lab 2 — Cross-VPC Connectivity via VPC Peering

> **Docs Site Version:** [`docs/gcp-labs/02-vpc-peering.md`](../../docs/gcp-labs/02-vpc-peering.md) · **Interactive HTML:** [`2-vpc_peering_architecture.html`](2-vpc_peering_architecture.html)

**VPC peering**: the simplest and free apart from egress. Subnet routes are exchanged **automatically**.

**HA VPN between the two VPCs**: you configure Cloud Routers, BGP sessions, and tunnels yourself. 
It teaches much more about routing, but it costs money while running (tunnels bill hourly).

---

## Architecture Diagrams

### Full Topology (`vpc-a` ↔ `vpc-b`)

![VPC Peering Full Architecture Diagram](../../docs/assets/diagrams/gcp-labs/2-vpc-peering-overview.svg)

### Layer 1: IAP Proxy (`35.235.240.0/20`) & Dual VPC Firewalls

![IAP Proxy and Dual VPC Firewalls](../../docs/assets/diagrams/gcp-labs/2-vpc-peering-iap-firewalls.svg)

### Layer 2: Bidirectional Peering Bridge (`a-to-b` & `b-to-a`) & Subnets

![Bidirectional VPC Peering Bridge and Subnets](../../docs/assets/diagrams/gcp-labs/2-vpc-peering-subnets-bridge.svg)

---

## VPC Peering
| Theory      | GCP Resurce                               |
|:------------|:------------------------------------------|
| VPC         | resource "google_compute_network"         |
| Subnet      | resource "google_compute_subnetwork"      |
| VPC Peering | resource "google_compute_network_peering" |
| Firewall    | resource "google_compute_firewall"        |
| Computer    | resource "google_compute_instance"        |


`35.235.240.0/20` is the source range Google’s Identity-Aware Proxy (IAP) uses when it forwards TCP connections to your VMs.

The VMs have no public IP, so your laptop can’t reach port 22 directly. With `--tunnel-through-iap`, the flow is:

```text
Your laptop → IAP (Google-managed) → VM port 22
```

The packets reaching the VM come from IAP’s range, `35.235.240.0/20`, not from your laptop’s IP. 
Since **GCP denies all ingress by default**, the firewall must allow that range on TCP 22, or SSH fails (the 4033/4003 errors).

What each part of your rule does
10.20.0.0/24 is the peer VPC’s subnet. Combined with ICMP, this lets VMs in VPC B ping VMs in VPC A. This is the peering-related part.
35.235.240.0/20 plus TCP 22 is for your SSH access only.
