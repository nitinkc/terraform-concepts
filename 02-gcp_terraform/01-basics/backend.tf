# Keeping the state file in the gcs bucket
# Create bucket prior to terraform plan -

# gsutil mb -l us-central1 gs://YOUR-UNIQUE-BUCKET-NAME-tfstate
terraform {
  backend "gcs" {
    bucket = "terraform-learning-tfstate"
    prefix = "acme-sampleapp/state"
  }
}