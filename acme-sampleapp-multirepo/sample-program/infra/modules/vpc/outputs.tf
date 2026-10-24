output "network_self_link" {
  value = google_compute_network.main.self_link
}

output "network_name" {
  value = google_compute_network.main.name
}

output "subnets" {
  description = "Map keyed the same as the input, each value the created subnetwork resource"
  value       = google_compute_subnetwork.subnet
}
