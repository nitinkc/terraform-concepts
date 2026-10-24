# Publishes this repo's outputs back to Consul, keyed by environment, in the
# exact shape backend/infra/main.tf expects when it decodes
# local.app_infra = jsondecode(data.consul_keys.remote_outputs.var.infrastructure)
#   .outputs.gcp.us_central1[env]

resource "consul_keys" "publish_outputs" {
  for_each = toset(local.available_environments)

  key {
    path = "gitlab/terraform_outputs/v2/sample-org/applications/acme-sampleapp/infrastructure/${each.key == "prod" ? "default" : each.key}"
    value = jsonencode({
      outputs = {
        gcp = {
          us_central1 = {
            (each.key) = {
              project_id    = local.program_gcp_by_env[each.key].gke.project
              sso_secret_id = google_secret_manager_secret.sso_config[each.key].secret_id
              # Non-sensitive — the OAuth public client identifier, safe to
              # publish in plain Consul output. frontend/infra reads this
              # directly; sso_client_secret never leaves Secret Manager.
              sso_client_id = var.sso_client_id
            }
          }
        }
      }
    })
  }
}
