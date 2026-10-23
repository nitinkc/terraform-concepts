resource "google_service_account" "gsa" {
  #   account_id   = "acme-web-app"
  account_id   = "${local.name_prefix}-web-app" # using local variable
  display_name = "My Test App"
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

resource "google_storage_bucket" "demo" {
  name     = "${local.name_prefix}-demo-${var.project_id}"
  location = "US"
  labels   = local.common_labels

  # your org has a policy enforcing uniform bucket-level access (no legacy ACLs), and the google_storage_bucket
  # resource defaults to uniform_bucket_level_access = false. Add the field explicitly:
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