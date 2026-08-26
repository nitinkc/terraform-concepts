# Publishes this repo's outputs to Consul in the exact shape
# backend/infra/cloudsql.tf expects when it decodes:
#   local.cloudsql = jsondecode(...).outputs.gcp.us_central1.acme_sampleapp

resource "consul_keys" "publish_outputs" {
  key {
    path = "gitlab/terraform_outputs/v2/sample-org/applications/acme-sampleapp/cloudsql/${terraform.workspace}"
    value = jsonencode({
      outputs = {
        gcp = {
          us_central1 = {
            acme_sampleapp = {
              project_id = local.program_gcp.gke.project
              cloud_sql_instance = {
                instance_name   = google_sql_database_instance.main.name
                connection_name = google_sql_database_instance.main.connection_name
              }
              cloud_function_urls = {
                grant_access  = google_cloudfunctions2_function.grant_access.url
                revoke_access = google_cloudfunctions2_function.revoke_access.url
              }
              database_name = var.database_name
              db_schema     = var.db_schema
            }
          }
        }
      }
    })
  }
}
