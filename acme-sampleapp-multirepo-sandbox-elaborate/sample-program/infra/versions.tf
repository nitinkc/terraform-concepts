terraform {
  required_version = ">= 1.7, < 2.0"

  # Swapped to local for this sandbox so it's runnable without bootstrapping
  # a GCS bucket first. In the real 4-repo project this is `backend "gcs" {}`
  # (partial config, filled in at `terraform init -backend-config=...`) — see
  # RUNBOOK.md for how to switch back once you want the practice.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.41.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "2.23.0"
    }
  }
}
