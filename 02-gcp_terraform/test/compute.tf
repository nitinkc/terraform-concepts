module "fde_vm" {
  source = "./modules/gcp-vm"

  instance_name = "fde-app-server"
  machine_type  = "e2-medium"
  zone          = "us-central1-a"
  subnetwork_id = google_compute_subnetwork.subnet.id
}

output "server_internal_ip" {
  value = module.fde_vm.instance_ip
}