# Two custom-mode VPCs
resource "google_compute_network" "network-a" {
  name                    = "vpc-a"
  auto_create_subnetworks = false
}
resource "google_compute_network" "network-b" {
  name                    = "vpc-b"
  auto_create_subnetworks = false
}


# Non-overlapping CIDRs (required for peering)
resource "google_compute_subnetwork" "subnet-a" {
  name          = "subnet-a"
  network       = google_compute_network.network-a.id
  region        = var.region
  ip_cidr_range = "10.10.0.0/24"
}
resource "google_compute_subnetwork" "subnet-b" {
  name          = "subnet-b"
  network       = google_compute_network.network-b.id
  region        = var.region
  ip_cidr_range = "10.20.0.0/24"
}

# Peering must be created from both sides
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

# Firewall: allow ICMP from the other VPC, SSH via IAP
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

# One small VM per VPC, no public IP
resource "google_compute_instance" "a" {
  name         = "vm-a"
  zone         = var.zone
  machine_type = "e2-micro"
  boot_disk {
    initialize_params { image = "debian-cloud/debian-12" }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet-a.id
  }
}
resource "google_compute_instance" "b" {
  name         = "vm-b"
  zone         = var.zone
  machine_type = "e2-micro"
  boot_disk {
    initialize_params { image = "debian-cloud/debian-12" }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet-b.id
  }
}

