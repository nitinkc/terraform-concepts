variable "project_id" {
  type        = string
  description = "GCP project ID everything in this sandbox deploys into"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP zone for zonal resources (the GKE clusters are zonal, not regional, to keep this cheap)"
  default     = "us-central1-a"
}

variable "dns_domain" {
  type        = string
  description = <<-EOT
    Domain name for the public managed zone (e.g. "sampleapp.example.com").
    Creating the zone doesn't require you to own/delegate the domain — it's a
    real, empty GCP resource either way — but nothing will actually resolve
    publicly unless you do delegate it. Fine to leave as a placeholder for
    this sandbox.
  EOT
  default     = "sampleapp.example.com"
}

# ──────────────────────────────────────────────
# GKE toggles — OFF by default. A real cluster costs real money even at the
# smallest size. Flip these to true in terraform.tfvars only when you're
# ready to actually apply, and destroy promptly when done.
# ──────────────────────────────────────────────

variable "enable_gke_p" {
  type        = bool
  description = "Create the 'p' (prod) GKE cluster. Costs money once true."
  default     = false
}

variable "enable_gke_np" {
  type        = bool
  description = "Create the 'np' (non-prod: dev/qa/review) GKE cluster. Costs money once true."
  default     = false
}

variable "gke_prod_machine_type" {
  type        = string
  default     = "e2-small"
}

variable "gke_nonprod_machine_type" {
  type        = string
  default     = "e2-small"
}

variable "gke_prod_node_count" {
  type        = number
  default     = 1
}

variable "gke_nonprod_node_count" {
  type        = number
  default     = 1
}
