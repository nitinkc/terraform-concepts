terraform {
  backend "gcs" {
    bucket = "my_gcs_bucket"
    prefix = "training/module-1"
  }
}