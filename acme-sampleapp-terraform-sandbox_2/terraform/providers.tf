data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = can(regex("^https?://", local.program_gcp.gke.host)) ? local.program_gcp.gke.host : "https://${local.program_gcp.gke.host}"
  cluster_ca_certificate = local.program_gcp.gke.cluster_ca_certificate
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  kubernetes = {
    host                   = can(regex("^https?://", local.program_gcp.gke.host)) ? local.program_gcp.gke.host : "https://${local.program_gcp.gke.host}"
    cluster_ca_certificate = local.program_gcp.gke.cluster_ca_certificate
    token                  = data.google_client_config.default.access_token
  }
}
