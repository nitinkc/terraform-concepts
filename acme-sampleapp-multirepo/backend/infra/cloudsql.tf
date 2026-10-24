# Cloud SQL connectivity for the backend.
#
# The database is owned by the separate acme-sampleapp/cloudsql repo, which
# publishes its outputs to Consul. Here we read those outputs and wire the
# deployment to the instance through a Cloud SQL Auth Proxy sidecar using IAM
# authentication (no password ever exists, so none can leak into state).

locals {
  cloudsql_raw = try(data.consul_keys.remote_outputs.var.cloudsql, "")
  cloudsql     = local.cloudsql_raw != "" ? try(jsondecode(local.cloudsql_raw).outputs.gcp.us_central1.acme_sampleapp, null) : null

  cloudsql_enabled         = local.cloudsql != null
  cloudsql_project_id      = try(local.cloudsql.project_id, "")
  cloudsql_connection_name = try(local.cloudsql.cloud_sql_instance.connection_name, "")
  cloudsql_instance_name   = try(local.cloudsql.cloud_sql_instance.instance_name, "")
  cloudsql_grant_url       = try(local.cloudsql.cloud_function_urls.grant_access, "")
  cloudsql_revoke_url      = try(local.cloudsql.cloud_function_urls.revoke_access, "")

  # Database, schema and owner-role names published by the cloudsql repo. The
  # try() fallbacks cover workspaces whose Consul outputs predate those fields.
  cloudsql_database_name = try(local.cloudsql.database_name, "sampleapp")
  cloudsql_db_schema     = try(local.cloudsql.db_schema, "sa-cloud-sql")

  cloudsql_region = "us-central1"
}
