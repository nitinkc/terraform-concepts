# Step 1 : Adding a service account (locally at step 1 and GCS bucket after step 2)
resource "google_service_account" "gsa" {
  # account_id   = "acme-web-app"
  # Step 8 : using locals
  account_id   = "${local.name_prefix}-web-app"
  display_name = "My Test App"
}

# Step 3 : Implicit Dependency on service account resource
# Service account is created first before creating IAM role membership
resource "google_project_iam_member" "sa_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  # implicit inference ordering Automatically
  member  = "serviceAccount:${google_service_account.gsa.email}"
  #depends_on = [google_service_account.gsa]
}


# Step 4: indexed multiple resources (adds 4 resources)
# creates dev and qa
# Prefer `for_each` over `count` - Reserve `count` for simple "N identical copies" or conditional 0/1 patterns.
resource "google_service_account" "env_sa_list" {
  count        = length(var.environment_list)
  account_id   = "acme-${var.environment_list[count.index]}" # get the names from the list
  display_name = "SA for ${var.environment_list[count.index]} env"
}

# Step 5: via set and For loop
# creates int and stg
resource "google_service_account" "env_sa_set" {
  for_each     = var.environment_set
  account_id   = "acme-${each.value}"
  display_name = "SA for ${each.value} env"
}

# Step 8 : Locals
locals {
  name_prefix = "acme"
  common_labels = {
    project     = var.project_id
    managed_by  = "terraform"
    environment = "sandbox"
  }
}

# Step 9 : using modules
module "backend_sa" {
  source       = "./modules/service_account"
  project_id   = var.project_id
  account_id   = "${local.name_prefix}-web-app-v2"
  display_name = "My Test App v2 (via module)"
}

# Step 10 - workspaces
resource "google_storage_bucket" "workspace_demo" {
  name                        = "${local.name_prefix}-${terraform.workspace}-demo-${var.project_id}"
  location                    = "US"
  uniform_bucket_level_access = true
  labels                      = local.common_labels
}

# Dynamic blocks
locals {
  lifecycle_rules = [
    { age = 30, storage_class = "NEARLINE" },
    { age = 90, storage_class = "COLDLINE" },
    { age = 365, storage_class = "ARCHIVE" },
  ]
}

resource "google_storage_bucket" "lifecycle_demo" {
  name                        = "${local.name_prefix}-lifecycle-${var.project_id}"
  location                    = "US"
  uniform_bucket_level_access = true

  dynamic "lifecycle_rule" {
    for_each = local.lifecycle_rules
    content {
      condition {
        age = lifecycle_rule.value.age
      }
      action {
        type          = "SetStorageClass"
        storage_class = lifecycle_rule.value.storage_class
      }
    }
  }
}

# Step 13 For-each over modules
module "app_sa" {
  source       = "./modules/service_account"
  for_each     = var.service_accounts
  project_id   = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
}

output "app_sa_emails" {
  value = {for k, m in module.app_sa : k => m.email}
}