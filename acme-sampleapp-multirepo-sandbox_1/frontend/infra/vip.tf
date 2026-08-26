# The frontend is the only piece of this stack with a public hostname — the
# backend is ClusterIP-only and reached in-cluster via nginx proxy (see
# backend/charts/.../values.yaml's comment on backend.service.type). This file
# owns that public identity: a static IP + DNS A record, consumed by the
# ingress values passed to helm_release in main.tf.

resource "google_compute_global_address" "frontend_vip" {
  project = local.program_gcp.gke.project
  name    = "acme-sampleapp-frontend${terraform.workspace == "default" ? "" : "-${local.workspace_suffix}"}-vip"
}

locals {
  host_name = trimsuffix(
    "sampleapp${terraform.workspace == "default" ? "" : "-${local.workspace_suffix}"}.${local.program_gcp.dns.public_zone.dns_name}",
    "."
  )
}

resource "google_dns_record_set" "frontend" {
  project      = local.program_gcp.gke.project
  managed_zone = local.program_gcp.dns.public_zone.name
  name         = "${local.host_name}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.frontend_vip.address]
}
