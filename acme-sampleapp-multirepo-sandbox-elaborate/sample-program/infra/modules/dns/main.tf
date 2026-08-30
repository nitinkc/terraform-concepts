resource "google_dns_managed_zone" "public" {
  project     = var.project_id
  name        = "sample-program-public-zone"
  dns_name    = "${var.domain}."
  description = "Public zone for acme-sampleapp — frontend/infra's vip.tf and Managed Certificate reference this."
  visibility  = "public"
}
