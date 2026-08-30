# Copy to terraform.tfvars and fill in real values.

docker_image_repo = "us-central1-docker.pkg.dev/my-devops-journey-502420/sampleapp/backend" # <-- your real Artifact Registry path, or any placeholder if you're only running `plan`
docker_image_tag  = "latest"

static_env = true # true only for the dev/qa workspaces, see backend/infra/main.tf's local.is_review_env

# Leave the AD group default as-is unless you actually have a matching group
# in your org — this only matters once you're applying the RBAC resources,
# not for provider auth.
# sampleapp_ops_ad_group = "gcp-sampleapp-ops@acme.com"
