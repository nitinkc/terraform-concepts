terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0" # This pins your provider version for stability
    }

    # required_providers is always required per provider you use; a provider {} config block is only
    # needed if that provider actually needs configuration.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

# check under IAM & Admin -> Service Account
resource "google_service_account" "gsa" {
  account_id   = "acme-web-app"
  display_name = "My Test App"
}

# resource "google_service_account_key" "my-key" {
#   service_account_id = google_service_account.gsa.name
#   public_key_type    = "TYPE_X509_PEM_FILE"
# }