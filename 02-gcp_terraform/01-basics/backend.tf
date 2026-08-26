# Keeping the state file in the gcs bucket
# Create bucket prior to terraform plan -

# gsutil mb -l us-central1 gs://YOUR-UNIQUE-BUCKET-NAME-tfstate
terraform {
  backend "gcs" {
    bucket = "terraform-learning-tfstate"
    prefix = "acme-sampleapp/state"
  }
}

resource "google_storage_bucket" "demo" {
  name     = "${local.name_prefix}-demo-${var.project_id}"
  location = "US"
  labels   = local.common_labels

  # your org has a policy enforcing uniform bucket-level access (no legacy ACLs), and the google_storage_bucket
  # resource defaults to uniform_bucket_level_access = false. Add the field explicitly:
  uniform_bucket_level_access = true
}