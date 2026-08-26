# Unlike backend, the frontend never touches Cloud SQL and never sees
# sso_client_secret — the SSO client_id is not sensitive (it's a public OAuth
# client identifier baked into any SPA bundle), so it's read directly from the
# infrastructure repo's Consul-published outputs in main.tf rather than via a
# Secret Manager IAM grant. That means this file is much smaller than
# backend/infra/iam.tf: there's no secretAccessor binding and no SQL roles to
# hand out. What's still needed is a dedicated GSA, kept for the same reason
# backend has one — app-scoped audit trails and a place to hang future
# permissions (e.g. Cloud CDN cache invalidation) without widening the
# default node service account.

resource "google_service_account" "app" {
  project      = local.program_gcp.gke.project
  account_id   = "sa-frontend${terraform.workspace == "default" ? "" : "-${local.workspace_suffix}"}"
  display_name = "Acme SampleApp Frontend (${local.namespace_name})"
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.app.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "serviceAccount:${local.program_gcp.gke.project}.svc.id.goog[${kubernetes_namespace_v1.main.metadata[0].name}/${local.frontend_sa_name}]"
}

# Lets the deploy pipeline (running as this GSA, via the same nginx container
# lifecycle hook pattern used for config injection) invalidate the CDN cache
# fronting static assets after a release, instead of waiting out the default
# TTL.
resource "google_project_iam_member" "cdn_cache_invalidator" {
  project = local.program_gcp.gke.project
  role    = "roles/compute.loadBalancerAdmin"
  member  = "serviceAccount:${google_service_account.app.email}"
}
