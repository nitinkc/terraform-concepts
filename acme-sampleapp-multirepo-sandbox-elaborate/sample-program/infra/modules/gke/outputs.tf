# Output field names deliberately match local.program_gcp.gke's expected
# shape in every downstream repo's providers.tf: .host, .cluster_ca_certificate,
# .name, .project. Don't rename these without updating the Consul publish in
# ../../main.tf and every consumer.

output "host" {
  value = "https://${google_container_cluster.main.endpoint}"
}

output "cluster_ca_certificate" {
  value     = base64decode(google_container_cluster.main.master_auth[0].cluster_ca_certificate)
  sensitive = true
}

output "name" {
  value = google_container_cluster.main.name
}

output "project" {
  value = var.project_id
}
