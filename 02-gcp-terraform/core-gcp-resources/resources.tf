# Step 1 : Adding a service account (locally at step 1 and GCS bucket after step 2)
resource "google_service_account" "gsa" {
  #   account_id   = "acme-web-app"
  # Step 8 : using locals -> local variable
  account_id   = "${local.name_prefix}-web-app"
  display_name = "My Test App"
}

# AM & Admin / Service accounts

# Step 4: indexed multiple resources (adds 4 resources)
# creates dev and qa
# Prefer `for_each` over `count` - Reserve `count` for simple "N identical copies" or conditional 0/1 patterns.
resource "google_service_account" "env_sa_set" {
  # used with   type    = set(string)
  for_each     = var.environment_set
  account_id   = "${local.name_prefix}-${each.value}" #get from local name prefix
  display_name = "SA for ${each.value} env"
}

resource "google_service_account" "env_sa_list" {
  # count is used with type    = list(string)
  count        = length(var.environment_list) # count — create multiple resources from one block
  account_id   = "acme-${var.environment_list[count.index]}"
  display_name = "SA for ${var.environment_list[count.index]} env"
}


# Step 3 : Implicit Dependency on service account resource
# Service account is created first before creating IAM role membership
# Check in console: IAM & Admin → IAM → find acme-web-app@... → confirm it has Cloud SQL Client role.
resource "google_project_iam_member" "sa_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  # implicit inference ordering Automatically
  member = "serviceAccount:${google_service_account.gsa.email}"
  #depends_on = [google_service_account.gsa]
}


# Step 10 - workspaces
resource "google_storage_bucket" "workspace_demo" {
  name                        = "${local.name_prefix}-${terraform.workspace}-demo-${var.project_id}"
  location                    = "US"
  uniform_bucket_level_access = true
  labels                      = local.common_labels
}

resource "google_storage_bucket" "demo" {
  name     = "${local.name_prefix}-demo-${var.project_id}"
  location = "US"
  labels   = local.common_labels

  # your org has a policy enforcing uniform bucket-level access (no legacy ACLs), and the google_storage_bucket
  # resource defaults to uniform_bucket_level_access = false. Add the field explicitly:
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "east_region_demo" {
  provider                    = google.us_east # using provider alias
  name                        = "${local.name_prefix}-east-${var.project_id}"
  location                    = "US-EAST1"
  uniform_bucket_level_access = true
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

