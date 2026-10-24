output "namespace" {
  description = "Kubernetes namespace the frontend is deployed into"
  value       = kubernetes_namespace_v1.main.metadata[0].name
}

output "frontend_url" {
  description = "Public HTTPS URL the frontend is reachable at"
  value       = "https://${local.host_name}"
}

output "service_account" {
  description = "Google service account (with workload identity) for the frontend"
  value = {
    id    = google_service_account.app.account_id
    email = google_service_account.app.email
  }
}
