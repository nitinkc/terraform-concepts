# Keeping the state file in a gcs bucket.
#
# Deliberately a *partial* configuration: no bucket, no prefix here. Terraform
# cannot create the bucket that holds its own state, so it has to exist before
# init, and hardcoding a globally-unique bucket name in a public repo just
# guarantees the next reader gets a permission error. Supply both at init time:
#
#   gsutil mb -l us-central1 gs://YOUR-UNIQUE-BUCKET-NAME-tfstate
#   terraform init \
#     -backend-config="bucket=YOUR-UNIQUE-BUCKET-NAME-tfstate" \
#     -backend-config="prefix=core-gcp-resources/state"
#
# An empty backend block still selects the gcs backend — that choice is code.
# Only the values are left to the operator.
terraform {
  backend "gcs" {
    bucket = "terraform-learning-tfstate"
    prefix = "acme-sampleapp/state"
  }
}
