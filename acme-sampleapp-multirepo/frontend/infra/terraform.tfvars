# Committed on purpose: every value here is a lab placeholder or a
# non-sensitive ID, so the sandbox runs without reconstructing tfvars first.
# `terraform.tfvars.example` is the annotated reference copy — edit this file
# in place. Real secrets never belong here; pass them via TF_VAR_* instead.

docker_image_repo = "us-central1-docker.pkg.dev/my-devops-journey-502420/sampleapp/frontend" # <-- your real Artifact Registry path, or any placeholder if you're only running `plan`
docker_image_tag  = "latest"

static_env = false

# Leave the AD group default as-is unless you actually have a matching group
# in your org — this only matters once you're applying the RBAC resources.
# sampleapp_ops_ad_group = "gcp-sampleapp-ops@acme.com"
