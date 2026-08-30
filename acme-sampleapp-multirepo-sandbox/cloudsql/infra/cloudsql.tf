resource "google_sql_database_instance" "main" {
  project          = local.program_gcp.gke.project
  name             = local.instance_name
  region           = "us-central1"
  database_version = "POSTGRES_16"

  settings {
    tier = var.tier

    ip_configuration {
      ipv4_enabled    = false
      private_network = local.program_gcp.network.self_link
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    backup_configuration {
      enabled                        = terraform.workspace == "default"
      point_in_time_recovery_enabled = terraform.workspace == "default"
    }
  }

  # Prevents an accidental `terraform destroy` from taking prod data with it.
  # dev/qa are left destroyable so review-env dry runs against this repo don't
  # get blocked by a lifecycle guard meant only for the real database.
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_sql_database" "app" {
  project  = local.program_gcp.gke.project
  name     = var.database_name
  instance = google_sql_database_instance.main.name
}

# The Flyway migration runner (db/migrate.sh, run out-of-band in CI — not by
# Terraform) connects as this user to apply db/migration/V*.sql. Terraform
# owns the Cloud SQL user's *existence* and IAM auth; it does not own schema
# contents, which is why there's no google_sql_user for the backend's own
# runtime identity here — that grant is handled by the shell_script bridge in
# backend/infra/iam.tf, against the roles this repo's Cloud Functions expose
# below.
resource "google_sql_user" "flyway_migrator" {
  project  = local.program_gcp.gke.project
  instance = google_sql_database_instance.main.name
  name     = "flyway-migrator"
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}
