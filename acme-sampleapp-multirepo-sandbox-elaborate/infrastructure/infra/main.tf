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

  program_outputs_raw = try(jsondecode(data.consul_keys.program.var.program).outputs.gcp.us_central1, {})

  # The shared platform ("program") repo publishes one GCP project per
  # permanent environment tier. This repo's resources fan out across all three
  # using for_each, rather than being deployed as three separate workspaces.
  #
  # Guarded with `if` here (not just try()) so that environments whose GKE
  # cluster hasn't been created yet are excluded from the map entirely,
  # rather than causing an "Invalid index" error. This lets the repo apply
  # successfully with only a subset of clusters up (e.g. lab use) instead of
  # hard-failing on the first missing one. secrets.tf and outputs.tf both
  # iterate `local.available_environments`, not the full `local.environments`
  # list, specifically so they stay in sync with this filter — using the full
  # list there while indexing this filtered map would just move the same
  # error one file downstream.
  program_gcp_by_env = {
    for env in local.environments :
    env => local.program_outputs_raw[env == "prod" ? "p" : "np"]
    if contains(keys(local.program_outputs_raw), env == "prod" ? "p" : "np")
  }

  available_environments = keys(local.program_gcp_by_env)
}
