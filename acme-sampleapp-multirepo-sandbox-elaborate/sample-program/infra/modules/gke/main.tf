# A deliberately minimal, zonal (not regional), single-node, spot-capable GKE
# cluster — cheapest realistic shape for a learning sandbox. Two real design
# decisions worth noticing even at this size:
#
# 1. `remove_default_node_pool = true` + a separate `google_container_node_pool`
#    below: the default node pool created inline with google_container_cluster
#    can't be resized/upgraded independently and isn't good practice even for
#    a toy cluster — better to build the habit now.
# 2. `workload_identity_config` is set unconditionally, even though this is a
#    single-node lab cluster. Every downstream repo (backend, frontend)
#    depends on Workload Identity existing — this cluster is the reason that
#    mechanism works at all.

# Dedicated node service account, rather than relying on the default Compute
# Engine service account (<project-number>-compute@developer.gserviceaccount.com).
# Two independent reasons to do this, not just one:
#   1. That default SA doesn't always exist — some projects never
#      auto-provision it, and even when they do there's an IAM propagation
#      delay right after first enabling the Compute Engine API.
#   2. Even when it does exist, it carries broad project Editor-level
#      permissions by default — every node trusting it is a real production
#      anti-pattern, not just a lab inconvenience. backend/infra and
#      frontend/infra already use dedicated GSAs for exactly this reason;
#      the node pool should too.
resource "google_service_account" "node" {
  project      = var.project_id
  account_id   = "${var.name}-node-sa"
  display_name = "GKE node SA for ${var.name}"
}

# Minimal roles a node actually needs to function — write logs/metrics, pull
# images. Nothing resembling Editor.
resource "google_project_iam_member" "node_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node.email}"
}

resource "google_container_cluster" "main" {
  project  = var.project_id
  name     = var.name
  location = var.zone # zonal, not var.region — one control plane replica, not three

  network    = var.network
  subnetwork = var.subnetwork

  remove_default_node_pool = true
  initial_node_count       = 1

  # Even with remove_default_node_pool = true, GKE still briefly creates a
  # transient initial node pool during cluster creation before Terraform
  # deletes it. That transient pool uses THIS node_config, not the separate
  # google_container_node_pool resource's config below — without this block,
  # the transient pool falls back to the (missing) default Compute Engine SA
  # and creation fails before it ever gets to the real node pool.
  node_config {
    service_account = google_service_account.node.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false # this is a lab cluster — make it easy to tear down

  depends_on = [google_project_iam_member.node_roles]
}

resource "google_container_node_pool" "main" {
  project    = var.project_id
  name       = "${var.name}-pool"
  cluster    = google_container_cluster.main.name
  location   = var.zone
  node_count = var.node_count

  node_config {
    machine_type    = var.machine_type
    spot            = var.spot
    service_account = google_service_account.node.email

    # Workload Identity has to be opted into on the node pool too, not just
    # the cluster — this is a common first-time gotcha.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # With an explicit service_account + IAM roles doing the real access
    # control, this broad-looking scope is just the ceiling — IAM is what
    # actually restricts what the node can do, not this.
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  depends_on = [google_project_iam_member.node_roles]
}
