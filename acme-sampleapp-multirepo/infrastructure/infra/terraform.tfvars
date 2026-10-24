# Committed on purpose: every value here is a lab placeholder or a
# non-sensitive ID, so the sandbox runs without reconstructing tfvars first.
# `terraform.tfvars.example` is the annotated reference copy — edit this file
# in place.
#
# sso_client_secret is the one variable here that would be sensitive in a real
# deployment. The value below is a placeholder that authenticates against
# nothing. A real one goes in TF_VAR_sso_client_secret in your shell, never in
# a file — which is precisely why committing this file is safe and committing
# a real one would not be.

sso_client_id     = "123456789-lab.apps.googleusercontent.com" # any placeholder is fine — nothing actually validates against a real IdP in this sandbox
sso_client_secret = "lab-placeholder-not-a-real-secret"
