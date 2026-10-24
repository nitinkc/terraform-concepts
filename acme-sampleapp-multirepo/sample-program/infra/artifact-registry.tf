resource "google_artifact_registry_repository" "sampleapp" {
  project       = var.project_id
  location      = var.region
  repository_id = "sampleapp"
  format        = "DOCKER"
}
