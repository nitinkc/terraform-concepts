terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Step 2 : Adding remote state (GCS Bucket)
  # acme-gcp-app-tfstate/acme-sampleapp/state/default.tfstate
  backend "gcs" {
    bucket = "acme-gcp-app-tfstate"
    prefix = "acme-sampleapp/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Strp 14 : Provider Aliasing (Multi-Region / Multi-Project)
provider "google" {
  alias   = "us_east"
  project = var.project_id
  region  = "us-east1"
}

resource "google_storage_bucket" "east_region_demo" {
  provider                    = google.us_east # using provider alias
  name                        = "${local.name_prefix}-east-${var.project_id}"
  location                    = "US-EAST1"
  uniform_bucket_level_access = true
}

