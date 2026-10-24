# The rule: a provider block's `project/region/zone` arguments are only a **default/fallback** — used only by resources
# that don't **explicitly** set their own project/region/zone.

provider "google" {
  project = var.project_id
  region  = var.region
}

# No explicit `provider "consul" {}` block — same convention as every other
# repo in this sandbox. The provider reads its address from the
# CONSUL_HTTP_ADDR environment variable (defaults to http://127.0.0.1:8500,
# which is exactly what `consul agent -dev` listens on — see RUNBOOK.md).
