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
