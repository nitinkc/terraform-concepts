# Grant/revoke of in-database roles (as opposed to GCP IAM roles) can't be
# expressed as a Terraform resource — Postgres GRANT/REVOKE happens over a SQL
# connection, not the GCP API. This repo exposes that as two small Cloud
# Functions that connect via the Cloud SQL Auth Proxy and run GRANT/REVOKE
# ROLE statements. Consuming repos (backend/infra) call these authenticated
# HTTP endpoints via the shell_script provider — see backend/infra/iam.tf.

resource "google_service_account" "grant_revoke_fn" {
  project      = local.program_gcp.gke.project
  account_id   = "acme-sampleapp-sql-grantor"
  display_name = "Cloud SQL grant/revoke function identity"
}

resource "google_project_iam_member" "grant_revoke_fn_sql_client" {
  project = local.program_gcp.gke.project
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.grant_revoke_fn.email}"
}

resource "google_cloudfunctions2_function" "grant_access" {
  project  = local.program_gcp.gke.project
  name     = "acme-sampleapp-${terraform.workspace}-grant-access"
  location = "us-central1"

  build_config {
    runtime     = "python312"
    entry_point = "grant_access"
    source {
      storage_source {
        bucket = "acme-sampleapp-cloudsql-functions-${terraform.workspace}"
        object = "grant_access.zip"
      }
    }
  }

  service_config {
    service_account_email = google_service_account.grant_revoke_fn.email
    environment_variables = {
      INSTANCE_CONNECTION_NAME = google_sql_database_instance.main.connection_name
      DB_SCHEMA                = var.db_schema
    }
  }
}

resource "google_cloudfunctions2_function" "revoke_access" {
  project  = local.program_gcp.gke.project
  name     = "acme-sampleapp-${terraform.workspace}-revoke-access"
  location = "us-central1"

  build_config {
    runtime     = "python312"
    entry_point = "revoke_access"
    source {
      storage_source {
        bucket = "acme-sampleapp-cloudsql-functions-${terraform.workspace}"
        object = "revoke_access.zip"
      }
    }
  }

  service_config {
    service_account_email = google_service_account.grant_revoke_fn.email
    environment_variables = {
      INSTANCE_CONNECTION_NAME = google_sql_database_instance.main.connection_name
      DB_SCHEMA                = var.db_schema
    }
  }
}

# Any caller that knows the function URL can attempt to invoke it; the
# function itself validates the caller's ID token against an allowlist of
# expected service accounts (this is why backend/infra's shell_script bridge
# generates an ID token via generateIdToken before calling GRANT_URL/REVOKE_URL).
resource "google_cloudfunctions2_function_iam_member" "callers" {
  for_each = toset([
    google_cloudfunctions2_function.grant_access.name,
    google_cloudfunctions2_function.revoke_access.name,
  ])

  project        = local.program_gcp.gke.project
  location       = "us-central1"
  cloud_function = each.value
  role           = "roles/cloudfunctions.invoker"
  # Allowlist is intentionally broad here (any SA in-project) — real
  # authorization happens inside the function via ID token audience checks.
  member = "serviceAccount:${google_service_account.grant_revoke_fn.email}"
}
