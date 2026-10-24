

# Lab 1 — Same-VPC Two-Subnet Connectivity & IAP SSH

> **Docs Site Version:** [`docs/gcp-labs/01-same-vpc-2-subnets.md`](../../docs/gcp-labs/01-same-vpc-2-subnets.md) · **Interactive HTML:** [`1-2subnet-connectivity.html`](1-2subnet-connectivity.html)

## Architecture Overview

![Same-VPC 2-Subnet Full Architecture Diagram](../../docs/assets/diagrams/gcp-labs/1-2subnet-overview.svg)

### Layer 1: Firewalls & IAP Ingress (`35.235.240.0/20` + Internal ICMP)

![Firewall and IAP Ingress Layer](../../docs/assets/diagrams/gcp-labs/1-2subnet-firewalls-iap.svg)

### Layer 2: Regional Subnets (`10.10.0.0/24` & `10.10.1.0/24`) & Private VMs

![Regional Subnets and VMs Layer](../../docs/assets/diagrams/gcp-labs/1-2subnet-subnets-vms.svg)

---

In Google Cloud (and Terraform), the **network_interface block** represents the Virtual Network Interface Card (**vNIC** / nic0) 
of your virtual machine.

```shell
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

## Use IAP for TCP forwarding

[Use IAP for TCP forwarding](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding)

```shell
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


`--tunnel-through-iap` option to connect via ssh
```shell
gcloud compute ssh vm-a --zone us-central1-a --tunnel-through-iap

# Run without interactive session

## From vm-a ping b
gcloud compute ssh vm-a --zone us-central1-a --tunnel-through-iap \
  --command "ping -c 4 vm-b"
  
## From vm-b ping a
gcloud compute ssh vm-b --zone us-central1-a --tunnel-through-iap \
  --command "ping -c 4 vm-a"
```


```shell
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud services enable compute.googleapis.com iap.googleapis.com
```
If you’re not the project Owner, your account needs the IAP-secured Tunnel User role (`roles/iap.tunnelResourceAccessor`) 
and permission to SSH to instances (e.g., Compute OS Login).