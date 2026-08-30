# Copy to terraform.tfvars and fill in real values.
# sso_client_secret is sensitive — better to pass it via
# TF_VAR_sso_client_secret in your shell than write it to a file at all, even
# a gitignored one. Included here as a placeholder for completeness.

sso_client_id     = "123456789-lab.apps.googleusercontent.com" # any placeholder is fine — nothing actually validates against a real IdP in this sandbox
sso_client_secret = "lab-placeholder-not-a-real-secret"
