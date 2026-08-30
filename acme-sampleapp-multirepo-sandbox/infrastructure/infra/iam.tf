# Grants secretAccessor to the SampleApp backend's GCP service account so it
# can read the SSO config at runtime. The GSA itself is created by
# backend/infra (main.tf's google_service_account.app) — this repo only knows
# its email because backend/infra's outputs are published back through
# Consul and read here, mirroring the reverse of the dependency backend/infra
# has on THIS repo's outputs. See Multirepo_helm_sandbox.md for the full dependency diagram.

data "consul_keys" "backend_outputs" {
  for_each = toset(local.environments)
  key {
    name = "backend"
    path = "gitlab/terraform_outputs/v2/sample-org/applications/acme-sampleapp/backend/${each.key == "prod" ? "default" : each.key}"
  }
}

locals {
  backend_sa_email_by_env = {
    for env in local.environments :
    env => try(jsondecode(data.consul_keys.backend_outputs[env].var.backend).service_account.email, null)
  }
}

resource "google_secret_manager_secret_iam_member" "backend_reads_sso_config" {
  for_each = {
    for env in local.environments : env => env
    if local.backend_sa_email_by_env[env] != null
  }

  secret_id = google_secret_manager_secret.sso_config[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.backend_sa_email_by_env[each.key]}"
}
