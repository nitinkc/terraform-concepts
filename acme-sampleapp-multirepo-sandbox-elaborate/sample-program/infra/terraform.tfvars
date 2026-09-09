# Committed on purpose: every value here is a lab placeholder or a
# non-sensitive ID, so the sandbox runs without reconstructing tfvars first.
# `terraform.tfvars.example` is the annotated reference copy — edit this file
# in place. Real secrets never belong here; pass them via TF_VAR_* instead.
#
# Production convention is the opposite — gitignore tfvars — see
# docs/theory/17-project-structure.md for why this repo deviates.

project_id = "my-devops-journey-502420" # <-- replace with your own GCP project ID
region     = "us-central1"
zone       = "us-central1-a"
dns_domain = "sampleapp.example.com" # placeholder is fine, doesn't need to resolve

# ──────────────────────────────────────────────
# GKE — OFF by default on purpose. Real money once true. Start with just
# enable_gke_np = true (cheaper, and it's the cluster dev/qa/review environments
# use) rather than turning both on at once.
# ──────────────────────────────────────────────
enable_gke_p  = false
enable_gke_np = true

# gke_prod_machine_type    = "e2-small"
gke_nonprod_machine_type = "e2-standard-2"
# gke_prod_node_count      = 1
# gke_nonprod_node_count   = 1
