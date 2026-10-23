

# Embed or dosomething for 2 subnet connectivity with 2subnet-connectivity.html


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