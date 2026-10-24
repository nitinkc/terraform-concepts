# This repo runs one workspace per permanent environment: dev, qa, default
# (prod) — the same convention backend/infra and frontend/infra use. There is
# deliberately no review-environment workspace here: review environments are
# expensive to spin a real database for, so backend/infra points them at the
# dev instance instead (see backend/infra/main.tf's data.consul_keys block).

data "consul_keys" "program" {
  key {
    name = "program"
    path = "gitlab/terraform_outputs/v2/sample-org/sample-program/default"
  }
}

locals {
  p_or_np     = terraform.workspace == "default" ? "p" : "np"
  program_gcp = jsondecode(data.consul_keys.program.var.program).outputs.gcp.us_central1[local.p_or_np]

  instance_name = "acme-sampleapp-${terraform.workspace}"
}
