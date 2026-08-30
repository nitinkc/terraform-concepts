output "instance_ip" {
  value       = google_compute_instance.vm.network_interface[0].network_ip
  description = "Internal IP of the provisioned VM"
}