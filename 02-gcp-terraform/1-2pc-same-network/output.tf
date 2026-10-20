output "vm_a_ip" {
  value = google_compute_instance.a.network_interface[0].network_ip
}

output "vm_b_ip" {
  value = google_compute_instance.b.network_interface[0].network_ip
}