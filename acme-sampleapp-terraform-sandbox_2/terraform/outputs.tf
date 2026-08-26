output "namespace" {
  description = "Kubernetes namespace the backend is deployed into"
  value       = kubernetes_namespace_v1.main.metadata[0].name
}

output "backend_service_url" {
  description = "Cluster-local base URL of the backend API. The frontend reads this from Consul so the hostname is never hardcoded there."
  value       = "http://acme-sampleapp-backend.${kubernetes_namespace_v1.main.metadata[0].name}.svc.cluster.local:8000"
}

output "service_account" {
  description = "Google service account (with workload identity) for the backend application."
  value = {
    id    = google_service_account.app.account_id
    email = google_service_account.app.email
  }
}

output "cloudsql_enabled" {
  description = "Whether this workspace resolved a Cloud SQL instance from the cloudsql repo's Consul outputs. False means the backend is running on mock data."
  value       = local.cloudsql_enabled
}
