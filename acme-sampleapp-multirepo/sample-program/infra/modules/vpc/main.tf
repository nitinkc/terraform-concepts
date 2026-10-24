# One shared VPC, two subnets (prod / non-prod) — mirrors the two GKE
# clusters this program repo publishes. Each subnet carries the secondary IP
# ranges GKE needs for VPC-native (alias IP) clusters: one range for Pod IPs,
# one for Service IPs. Without these, google_container_cluster's
# ip_allocation_policy block (in the gke module) has nothing to point at.

resource "google_compute_network" "main" {
  project                 = var.project_id
  name                    = "sample-program-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  for_each = var.subnets

  project       = var.project_id
  name          = "sample-program-${each.key}"
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = each.value.primary_cidr

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = each.value.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = each.value.services_cidr
  }
}

# Cloud NAT so nodes without external IPs (the default for GKE nodes) can
# still reach the internet — pull images, hit Secret Manager, etc.
resource "google_compute_router" "main" {
  project = var.project_id
  name    = "sample-program-router"
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  project                            = var.project_id
  name                                = "sample-program-nat"
  router                              = google_compute_router.main.name
  region                              = var.region
  nat_ip_allocate_option              = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
