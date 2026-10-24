# ==============================================================================
# 1. Two Custom-Mode VPCs & Non-Overlapping Subnets
# ==============================================================================
# Unlike VPC Peering (where GCP exchanges subnet routes automatically in the
# control plane), HA VPN connects two networks via encrypted IPsec tunnels
# (data plane) and exchanges routes dynamically via Cloud Router + eBGP.
#
# Why GLOBAL routing mode?
# - REGIONAL (default): Cloud Router only advertises/programs routes in its own region.
# - GLOBAL: Cloud Router advertises subnets from ALL regions and learns dynamic
#   routesVPC-wide. Always use GLOBAL in enterprise Hub-and-Spoke / Hybrid VPNs.

resource "google_compute_network" "network_a" {
  name                    = "vpn-vpc-a"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_network" "network_b" {
  name                    = "vpn-vpc-b"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "subnet_a" {
  name          = "vpn-subnet-a"
  network       = google_compute_network.network_a.id
  region        = var.region
  ip_cidr_range = "10.10.0.0/24"
}

resource "google_compute_subnetwork" "subnet_b" {
  name          = "vpn-subnet-b"
  network       = google_compute_network.network_b.id
  region        = var.region
  ip_cidr_range = "10.20.0.0/24"
}

# ==============================================================================
# 2. Cloud Routers (Control Plane — BGP Speakers)
# ==============================================================================
# Cloud Router is NOT a data-plane appliance — traffic never flows through it!
# It is purely a BGP control-plane speaker that exchanges prefixes over the
# tunnel's 169.254.x.x link-local IPs and programs learned routes into the VPC.
#
# Each side needs a distinct private ASN (64512–65534) so they form an eBGP
# (External BGP) peering session:
#   Router A = ASN 65001
#   Router B = ASN 65002

resource "google_compute_router" "router_a" {
  name    = "ha-vpn-router-a"
  network = google_compute_network.network_a.name
  region  = var.region

  bgp {
    asn                = var.asn_a
    advertise_mode     = "DEFAULT" # Automatically advertises all subnets in vpc-a
    keepalive_interval = 20        # Seconds between BGP keepalives (failover ~60s)
  }
}

resource "google_compute_router" "router_b" {
  name    = "ha-vpn-router-b"
  network = google_compute_network.network_b.name
  region  = var.region

  bgp {
    asn                = var.asn_b
    advertise_mode     = "DEFAULT" # Automatically advertises all subnets in vpc-b
    keepalive_interval = 20
  }
}

# ==============================================================================
# 3. HA VPN Gateways (Data Plane — 99.99% SLA Dual-Interface Gateways)
# ==============================================================================
# Unlike Classic VPN, a single `google_compute_ha_vpn_gateway` automatically
# provisions TWO independent external public IPs from distinct failure domains:
#   - Interface 0 (vpn_interfaces[0])
#   - Interface 1 (vpn_interfaces[1])
# You do NOT reserve `google_compute_address` resources manually for HA VPN.

resource "google_compute_ha_vpn_gateway" "ha_gateway_a" {
  name    = "ha-vpn-gw-a"
  network = google_compute_network.network_a.id
  region  = var.region
}

resource "google_compute_ha_vpn_gateway" "ha_gateway_b" {
  name    = "ha-vpn-gw-b"
  network = google_compute_network.network_b.id
  region  = var.region
}

# ==============================================================================
# 4. IPsec Tunnels (2 Parallel Active/Active Tunnels per Direction = 4 Total)
# ==============================================================================
# To achieve the 99.99% SLA between two GCP HA VPN gateways:
#   - Interface 0 on Gateway A <===> Interface 0 on Gateway B
#   - Interface 1 on Gateway A <===> Interface 1 on Gateway B
#
# Notice `peer_gcp_gateway`: when connecting GCP-to-GCP, you point directly to
# the peer `google_compute_ha_vpn_gateway`. (When connecting GCP to On-Premises
# Cisco/Palo Alto/AWS, you would instead use `google_compute_external_vpn_gateway`
# and `peer_external_gateway`).

resource "random_password" "vpn_shared_secret" {
  length  = 32
  special = false
}

# --- VPC A -> VPC B Tunnels ---
resource "google_compute_vpn_tunnel" "a_to_b_if0" {
  name                  = "tunnel-a-to-b-if0"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway_a.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_gateway_b.id
  shared_secret         = random_password.vpn_shared_secret.result
  router                = google_compute_router.router_a.id
  vpn_gateway_interface = 0
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "a_to_b_if1" {
  name                  = "tunnel-a-to-b-if1"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway_a.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_gateway_b.id
  shared_secret         = random_password.vpn_shared_secret.result
  router                = google_compute_router.router_a.id
  vpn_gateway_interface = 1
  ike_version           = 2
}

# --- VPC B -> VPC A Tunnels ---
resource "google_compute_vpn_tunnel" "b_to_a_if0" {
  name                  = "tunnel-b-to-a-if0"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway_b.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_gateway_a.id
  shared_secret         = random_password.vpn_shared_secret.result
  router                = google_compute_router.router_b.id
  vpn_gateway_interface = 0
  ike_version           = 2
}

resource "google_compute_vpn_tunnel" "b_to_a_if1" {
  name                  = "tunnel-b-to-a-if1"
  region                = var.region
  vpn_gateway           = google_compute_ha_vpn_gateway.ha_gateway_b.id
  peer_gcp_gateway      = google_compute_ha_vpn_gateway.ha_gateway_a.id
  shared_secret         = random_password.vpn_shared_secret.result
  router                = google_compute_router.router_b.id
  vpn_gateway_interface = 1
  ike_version           = 2
}

# ==============================================================================
# 5. Cloud Router Interfaces & BGP Peers (Link-Local 169.254.x.x/30 Handshake)
# ==============================================================================
# Even once IPsec tunnels are UP (Phase 1 & Phase 2 IKEv2 established), NO
# traffic can route yet! Each tunnel needs:
#   1. A `google_compute_router_interface` binding the tunnel to a `/30`
#      link-local APIPA address (`169.254.x.x/30`).
#   2. A `google_compute_router_peer` telling the Cloud Router the remote peer's
#      link-local IP and ASN (`65001` <-> `65002`).
#
# Subnets used inside the tunnels:
#   - Tunnel Interface 0 pair: 169.254.0.0/30  (A = 169.254.0.1, B = 169.254.0.2)
#   - Tunnel Interface 1 pair: 169.254.1.0/30  (A = 169.254.1.1, B = 169.254.1.2)

# --- Router A: Interface 0 & BGP Peer 0 ---
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
  peer_asn                  = var.asn_b
  advertised_route_priority = 100 # MED (Multi-Exit Discriminator): equal 100 on both = ECMP active/active
  interface                 = google_compute_router_interface.router_a_if0.name
}

# --- Router A: Interface 1 & BGP Peer 1 ---
resource "google_compute_router_interface" "router_a_if1" {
  name       = "router-a-if1"
  router     = google_compute_router.router_a.name
  region     = var.region
  ip_range   = "169.254.1.1/30"
  vpn_tunnel = google_compute_vpn_tunnel.a_to_b_if1.name
}

resource "google_compute_router_peer" "router_a_peer1" {
  name                      = "bgp-a-to-b-if1"
  router                    = google_compute_router.router_a.name
  region                    = var.region
  peer_ip_address           = "169.254.1.2"
  peer_asn                  = var.asn_b
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.router_a_if1.name
}

# --- Router B: Interface 0 & BGP Peer 0 ---
resource "google_compute_router_interface" "router_b_if0" {
  name       = "router-b-if0"
  router     = google_compute_router.router_b.name
  region     = var.region
  ip_range   = "169.254.0.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.b_to_a_if0.name
}

resource "google_compute_router_peer" "router_b_peer0" {
  name                      = "bgp-b-to-a-if0"
  router                    = google_compute_router.router_b.name
  region                    = var.region
  peer_ip_address           = "169.254.0.1"
  peer_asn                  = var.asn_a
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.router_b_if0.name
}

# --- Router B: Interface 1 & BGP Peer 1 ---
resource "google_compute_router_interface" "router_b_if1" {
  name       = "router-b-if1"
  router     = google_compute_router.router_b.name
  region     = var.region
  ip_range   = "169.254.1.2/30"
  vpn_tunnel = google_compute_vpn_tunnel.b_to_a_if1.name
}

resource "google_compute_router_peer" "router_b_peer1" {
  name                      = "bgp-b-to-a-if1"
  router                    = google_compute_router.router_b.name
  region                    = var.region
  peer_ip_address           = "169.254.1.1"
  peer_asn                  = var.asn_a
  advertised_route_priority = 100
  interface                 = google_compute_router_interface.router_b_if1.name
}

# ==============================================================================
# 6. Firewalls & Test VMs (Data-Plane Verification)
# ==============================================================================
# CRITICAL GOTCHA: Even when BGP is ESTABLISHED and routes are in the VPC route
# table, GCP's implied deny-all ingress firewall still blocks traffic from the
# remote VPC's CIDR until explicitly allowed.

resource "google_compute_firewall" "a_allow" {
  name          = "vpn-vpc-a-allow"
  network       = google_compute_network.network_a.name
  source_ranges = ["10.20.0.0/24", "35.235.240.0/20"]

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "b_allow" {
  name          = "vpn-vpc-b-allow"
  network       = google_compute_network.network_b.name
  source_ranges = ["10.10.0.0/24", "35.235.240.0/20"]

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "vm_a" {
  name         = "vpn-vm-a"
  zone         = var.zone
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_a.id
  }
}

resource "google_compute_instance" "vm_b" {
  name         = "vpn-vm-b"
  zone         = var.zone
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_b.id
  }
}
