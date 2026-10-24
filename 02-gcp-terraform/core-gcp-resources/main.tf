terraform {
  # Pin the CLI itself, not just the providers — every sandbox root does the
  # same. Without it, a config using newer syntax fails as a parse error on a
  # colleague's older CLI instead of a clear version message.
  required_version = ">= 1.7, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0" # This pins your provider version for stability
    }

    # required_providers is always required per provider you use; a provider {} config block is only
    # needed if that provider actually needs configuration.
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Default provider (unaliased) — inherited by all resources and child modules by default
provider "google" {
  project = var.project_id
  region  = var.region
}

# Step 14 : Provider Aliasing (Multi-Region / Multi-Project)
# A provider block with an alias is only used by resources that
# explicitly set provider = google.us_east (like google_storage_bucket.east_region_demo)
provider "google" {
  alias   = "us_east" # Provider Aliasing
  project = var.project_id
  region  = "us-east1"
}

# Step 9 : using modules
module "backend_sa" {
  source       = "./modules/service_account"
  project_id   = var.project_id
  account_id   = "${local.name_prefix}-web-app-v2"
  display_name = "My Test App v2 (via module)"
}

# Step 13 For-each over modules
module "app_sa" {
  source       = "./modules/service_account"
  for_each     = var.service_accounts
  project_id   = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
}


