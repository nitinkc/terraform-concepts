# SSO configuration shared by every SampleApp application (backend + frontend)
# in a given environment. Owned here rather than in backend/infra because it's
# not backend-specific — the frontend reads the client ID directly, and any
# future SampleApp service would need the same secret rather than a copy.

resource "google_secret_manager_secret" "sso_config" {
  for_each  = toset(local.environments)
  project   = local.program_gcp_by_env[each.key].gke.project
  secret_id = "acme-sampleapp-sso-config-${each.key}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "sso_config" {
  for_each = toset(local.environments)
  secret   = google_secret_manager_secret.sso_config[each.key].id

  secret_data = jsonencode({
    client_id     = var.sso_client_id
    client_secret = var.sso_client_secret
  })
}
