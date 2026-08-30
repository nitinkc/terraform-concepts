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

# The `output` blocks above land in this repo's own state file only — visible
# via `terraform output` or `terraform_remote_state`, but invisible to a
# different repo's plan/apply unless that repo also has this repo's backend
# config wired up. This repo doesn't use terraform_remote_state anywhere
# (see cloudsql.tf's header comment), so cross-repo visibility instead goes
# through this resource: it republishes the same values to Consul, in the
# exact shape frontend/infra/main.tf expects when it decodes
# `jsondecode(data.consul_keys.remote_outputs.var.backend).backend_service_url`.
resource "consul_keys" "publish_outputs" {
  key {
    path = "gitlab/terraform_outputs/v2/sample-org/applications/acme-sampleapp/backend/${terraform.workspace}"
    value = jsonencode({
      backend_service_url = "http://acme-sampleapp-backend.${kubernetes_namespace_v1.main.metadata[0].name}.svc.cluster.local:8000"
      service_account = {
        id    = google_service_account.app.account_id
        email = google_service_account.app.email
      }
    })
  }
}
