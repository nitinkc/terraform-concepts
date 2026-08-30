# This repo runs a single "default" workspace and publishes one set of outputs
# per logical environment (dev / qa / prod) under that workspace — unlike
# backend and frontend, it does not use terraform.workspace per-environment.
# Consumers key into these outputs by environment name themselves (see
# backend/infra/main.tf's local.infra_env_key).

data "consul_keys" "program" {
  key {
    name = "program"
    path = "gitlab/terraform_outputs/v2/sample-org/sample-program/default"
  }
}

locals {
  environments = ["dev", "qa", "prod"]

  # The shared platform ("program") repo publishes one GCP project per
  # permanent environment tier. This repo's resources fan out across all three
  # using for_each, rather than being deployed as three separate workspaces.
  program_gcp_by_env = {
    for env in local.environments :
    env => jsondecode(data.consul_keys.program.var.program).outputs.gcp.us_central1[env == "prod" ? "p" : "np"]
  }
}
