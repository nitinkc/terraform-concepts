data "google_project" "current" {
  project_id = var.project_id
}

# terraform output project_number
output "project_number" {
  value = data.google_project.current.number
}

data "google_compute_network" "default" {
  name = google_compute_network.vpc.name
}

# terraform output default_network_self_link
output "default_network_self_link" {
  value = data.google_compute_network.default.self_link
}

