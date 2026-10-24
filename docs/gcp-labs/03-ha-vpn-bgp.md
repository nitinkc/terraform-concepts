# Lab 3 — HA VPN with Cloud Router & Dynamic eBGP

**Code:** `02-gcp-terraform/3-ha-vpn-bgp/` · **Resources Planned:** `25` · **Interactive View:** [Open Interactive Dashboard :material-open-in-new:](dashboards/3-ha-vpn-bgp-architecture.html){ target="_blank" }

---

## 1. Full Topology Overview

In [Lab 2 (VPC Peering)](02-vpc-peering.md), GCP exchanged routes between `10.10.0.0/24` and `10.20.0.0/24` automatically in the SDN control plane. In this lab, we connect the **exact same two subnets** using **HA VPN (`99.99% SLA`) + Cloud Router + Dynamic eBGP** across **4 active/active IKEv2 IPsec tunnels**.

Because the full 25-resource diagram is rich in detail, it is presented below as a full overview followed by **three focused sub-diagrams** (Workloads & Firewalls, Cloud Routers & HA VPN Gateways, and the Dual IPsec Tunnel / BGP Mesh Channel).

[![HA VPN and BGP Full Architecture Overview](../assets/diagrams/gcp-labs/3-ha-vpn-overview.svg)](../assets/diagrams/gcp-labs/3-ha-vpn-overview.svg)

*Click any diagram to zoom in full screen, or [launch the interactive HTML inspector](dashboards/3-ha-vpn-bgp-architecture.html){ target="_blank" }.*

!!! warning "Hourly Tunnel Billing"
    Unlike VPC Peering, VPN tunnels bill hourly (`~$0.05/tunnel/hour` × 4 tunnels = `~$0.20/hr`). Always run `terraform destroy` right after testing live BGP sessions.

---

## 2. Visual Breakdown by Subsystem (3 Focused Views)

### Part A — VPCs (`GLOBAL` Routing), Subnets, VMs & Ingress Firewalls

Unlike Lab 2 where default `REGIONAL` routing sufficed, both `vpn-vpc-a` and `vpn-vpc-b` set **`routing_mode = "GLOBAL"`** so Cloud Router advertises subnets from all regions and programs learned BGP routes VPC-wide:

[![HA VPN Workloads, Subnets and Firewalls](../assets/diagrams/gcp-labs/3-ha-vpn-workloads-firewalls.svg)](../assets/diagrams/gcp-labs/3-ha-vpn-workloads-firewalls.svg)

- **`vpn-vpc-a` (`10.10.0.0/24`):** Hosts `vpn-vm-a` and firewall `vpn-vpc-a-allow` (permits ICMP + TCP `22` from `10.20.0.0/24` and IAP `35.235.240.0/20`).
- **`vpn-vpc-b` (`10.20.0.0/24`):** Hosts `vpn-vm-b` and firewall `vpn-vpc-b-allow` (permits ICMP + TCP `22` from `10.10.0.0/24` and IAP `35.235.240.0/20`).

---

### Part B — Control Plane vs. Data Plane: Cloud Routers & HA VPN Gateways

A critical architectural distinction in Google Cloud hybrid networking is the separation between **Cloud Router (Control Plane)** and **HA VPN Gateway (Data Plane)**:

[![Cloud Routers and HA VPN Gateways](../assets/diagrams/gcp-labs/3-ha-vpn-routers-gateways.svg)](../assets/diagrams/gcp-labs/3-ha-vpn-routers-gateways.svg)

1. **Cloud Routers (`ha-vpn-router-a` & `ha-vpn-router-b`) — Pure Control Plane:**
   - User data packets **never** pass through Cloud Router.
   - Cloud Router is purely a **BGP speaker** that establishes TCP port `179` sessions over the tunnel's link-local `169.254.x.x/30` IPs, exchanges prefix advertisements (`10.10.0.0/24` ↔ `10.20.0.0/24`), and programs next-hop routes into the VPC route table.
   - **Why two different ASNs (`65001` vs. `65002`)?** BGP between two autonomous networks uses **eBGP (External BGP)**, which requires distinct private ASNs (`64512`–`65534` per RFC 6996).
2. **HA VPN Gateways (`ha-vpn-gw-a` & `ha-vpn-gw-b`) — Dual-Interface Data Plane:**
   - Each `google_compute_ha_vpn_gateway` automatically allocates **two independent external IPv4 addresses** (`GW IF 0` and `GW IF 1`) backed by separate physical/logical failure domains in GCP. You never create `google_compute_address` resources manually for HA VPN.

```hcl
resource "google_compute_router" "router_a" {
  name    = "ha-vpn-router-a"
  network = google_compute_network.network_a.name
  region  = var.region

  bgp {
    asn                = var.asn_a # 65001 (Router B uses 65002)
    advertise_mode     = "DEFAULT" # Automatically advertises all VPC subnets
    keepalive_interval = 20
  }
}

resource "google_compute_ha_vpn_gateway" "ha_gateway_a" {
  name    = "ha-vpn-gw-a"
  network = google_compute_network.network_a.id
  region  = var.region
}
```

---

### Part C — Dual IPsec Tunnels (`if0 ↔ if0`, `if1 ↔ if1`) & `169.254.x.x/30` BGP Mesh

Even after all 4 IKEv2 IPsec tunnels (`a_to_b_if0`, `a_to_b_if1`, `b_to_a_if0`, `b_to_a_if1`) authenticate using `random_password.vpn_shared_secret`, **no routes exist until BGP peers are bound to each tunnel**:

[![Dual IPsec Tunnels and BGP Session Mesh](../assets/diagrams/gcp-labs/3-ha-vpn-bgp-tunnels.svg)](../assets/diagrams/gcp-labs/3-ha-vpn-bgp-tunnels.svg)

| Tunnel Pair | Gateway Interface | Router A (`ASN 65001`) | Router B (`ASN 65002`) | Route Priority (MED) | Mode |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Primary Tunnel 0** | `if0 ↔ if0` | `169.254.0.1/30` (`router-a-if0`) | `169.254.0.2/30` (`router-b-if0`) | `100` | Active (ECMP) |
| **Secondary Tunnel 1** | `if1 ↔ if1` | `169.254.1.1/30` (`router-a-if1`) | `169.254.1.2/30` (`router-b-if1`) | `100` | Active (ECMP) |

- **Why `169.254.x.x/30`?** An IPsec tunnel is a virtual point-to-point wire. To run TCP port `179` (BGP) inside that wire, each end of the tunnel needs an IP from a non-routable RFC 3927 link-local `/30` subnet (`2` usable host IPs per `/30`).
- **Active/Active ECMP vs. Active/Passive (`advertised_route_priority`):** Both Tunnel 0 and Tunnel 1 advertise prefixes with `advertised_route_priority = 100` (BGP **MED** — Multi-Exit Discriminator; lower number = higher preference). Because both tunnels have equal cost (`100`), GCP installs **both tunnels simultaneously** as Equal-Cost Multi-Path (**ECMP**) next hops. To make Tunnel 1 a passive standby instead, set its `advertised_route_priority = 200`.

```hcl
# Bind Tunnel 0 on Router A to 169.254.0.1/30 and peer with Router B (169.254.0.2, ASN 65002)
resource "google_compute_router_interface" "router_a_if0" {
  name       = "router-a-if0"
  router     = google_compute_router.router_a.name
  region     = var.region
  ip_range   = "169.254.0.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.a_to_b_if0.name
}

resource "google_compute_router_peer" "router_a_peer0" {
  name                      = "bgp-a-to-b-if0"
  router                    = google_compute_router.router_a.name
  region                    = var.region
  peer_ip_address           = "169.254.0.2"
  peer_asn                  = var.asn_b # 65002
  advertised_route_priority = 100       # Equal MED (100) on both tunnels => Active/Active ECMP
  interface                 = google_compute_router_interface.router_a_if0.name
}
```

---

## 3. Resource Inventory (`25` Resources)

| Layer | Terraform Resource Type | Count | Identifiers |
| :--- | :--- | :--- | :--- |
| **1. Global VPCs & Subnets** | `google_compute_network`, `google_compute_subnetwork` | `4` | `network_a`, `network_b`, `subnet_a` (`10.10.0.0/24`), `subnet_b` (`10.20.0.0/24`) |
| **2. Cloud Routers (Control Plane)** | `google_compute_router` | `2` | `router_a` (`ASN 65001`), `router_b` (`ASN 65002`) |
| **3. HA VPN Gateways (Data Plane)** | `google_compute_ha_vpn_gateway` | `2` | `ha_gateway_a`, `ha_gateway_b` (2 auto-allocated public IPs each) |
| **4. Shared Secret & IPsec Tunnels** | `random_password`, `google_compute_vpn_tunnel` | `5` | `vpn_shared_secret`, `a_to_b_if0`, `a_to_b_if1`, `b_to_a_if0`, `b_to_a_if1` |
| **5. Router Interfaces & BGP Peers** | `google_compute_router_interface`, `google_compute_router_peer` | `8` | `router_a_if0/1`, `router_b_if0/1`, `router_a_peer0/1`, `router_b_peer0/1` |
| **6. Firewalls & Test VMs** | `google_compute_firewall`, `google_compute_instance` | `4` | `a_allow`, `b_allow`, `vm_a`, `vm_b` |

---

## 4. Verification Commands

```bash
# 1. Initialize & validate the 25-resource plan (free)
terraform init
terraform plan

# 2. If applied to test live BGP, inspect all 4 IPsec tunnels
gcloud compute vpn-tunnels list --filter="region:us-central1"

# 3. Verify BGP session status (state: ESTABLISHED) and learned prefixes on Router A
gcloud compute routers get-status ha-vpn-router-a \
  --region=us-central1 \
  --format="yaml(result.bgpPeerStatus, result.bestRoutesForRouter)"

# 4. Inspect VPC A's route table — observe two equal-cost (priority 100) next-hop tunnels for 10.20.0.0/24
gcloud compute routes list --filter="network:vpn-vpc-a"

# 5. Ping vpn-vm-b from vpn-vm-a across the encrypted IPsec tunnel
gcloud compute ssh vpn-vm-a --zone=us-central1-a --tunnel-through-iap \
  --command="ping -c 4 $(terraform output -raw vm_b_ip)"

# 6. Tear down immediately to stop hourly tunnel charges
terraform destroy
```

---

## 5. Interactive Inspector (Embedded)

??? example "Expand Interactive Component Inspector inline"
    <iframe src="../dashboards/3-ha-vpn-bgp-architecture.html" width="100%" height="840" style="border: 1px solid #23314d; border-radius: 12px;" loading="lazy"></iframe>
