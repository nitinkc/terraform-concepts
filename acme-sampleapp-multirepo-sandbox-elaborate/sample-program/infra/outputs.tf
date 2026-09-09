output "vpc_network" {
  value = module.vpc.network_name
}

output "gke_clusters_created" {
  description = "Which of 'p'/'np' actually got a cluster this apply"
  value       = keys(local.gke_clusters_enabled)
}

output "dns_name_servers" {
  description = "Delegate your domain to these if you want the public zone to actually resolve"
  value       = module.dns.public_zone.name_servers
}

output "mock_backend_image" {
  description = "Artifact Registry image populated by restore-session.sh for the sandbox backend"
  value       = "${google_artifact_registry_repository.sampleapp.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.sampleapp.repository_id}/backend:latest"
}
