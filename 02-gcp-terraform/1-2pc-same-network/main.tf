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

resource "google_compute_subnetwork" "b" {
  name          = "subnet-b"
  network       = google_compute_network.main.id
  region        = var.region
  ip_cidr_range = "10.10.1.0/24"
}

resource "google_compute_instance" "b" {
  name         = "vm-b"
  zone         = var.zone
  machine_type = "e2-micro"
  boot_disk {
    initialize_params { image = "debian-cloud/debian-12" }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.b.id
  }
}

# Allow ICMP between subnets, and SSH via IAP (Identity Aware Proxy) only
resource "google_compute_firewall" "internal_icmp" {
  name          = "allow-internal-icmp"
  network       = google_compute_network.main.name
  source_ranges = ["10.10.0.0/16"]
  allow { protocol = "icmp" }
}

# https://docs.cloud.google.com/iap/docs/using-tcp-forwarding
resource "google_compute_firewall" "iap_ssh" {
  name          = "allow-iap-ssh"
  network       = google_compute_network.main.name
  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}