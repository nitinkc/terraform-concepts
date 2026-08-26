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


locals {
  name_prefix = "acme"
  common_labels = {
    project     = var.project_id
    managed_by  = "terraform"
    environment = "sandbox"
  }
}

resource "google_service_account" "gsa" {
  #   account_id   = "acme-web-app"
  account_id   = "${local.name_prefix}-web-app" # using local variable
  display_name = "My Test App"
}

output "service_account" {
  description = "Google service account (with workload identity) for the backend application."
  value = {
    id    = google_service_account.gsa.account_id
    email = google_service_account.gsa.email
  }
}

# AM & Admin / Service accounts
resource "google_service_account" "env_sa" {
  # count is used with type    = list(string)

  # count        = length(var.environments) # count — create multiple resources from one block
  # account_id   = "acme-${var.environments[count.index]}"
  # display_name = "SA for ${var.environments[count.index]} env"

  # used with   type    = set(string)
  for_each     = var.environments
  account_id   = "${local.name_prefix}-${each.value}" #get from local name prefix
  display_name = "SA for ${each.value} env"
}


# Check in console: IAM & Admin → IAM → find acme-web-app@... → confirm it has Cloud SQL Client role.
resource "google_project_iam_member" "sa_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.gsa.email}"
}

# resource "google_service_account_key" "my-key" {
#   service_account_id = google_service_account.gsa.name
#   public_key_type    = "TYPE_X509_PEM_FILE"
# }