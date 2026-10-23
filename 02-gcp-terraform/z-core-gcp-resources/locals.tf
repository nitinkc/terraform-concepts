locals {
  name_prefix = "acme"
  common_labels = {
    project     = var.project_id
    managed_by  = "terraform"
    environment = "sandbox"
  }
  lifecycle_rules = [
    { age = 30, storage_class = "NEARLINE" },
    { age = 90, storage_class = "COLDLINE" },
    { age = 365, storage_class = "ARCHIVE" },
  ]
}
