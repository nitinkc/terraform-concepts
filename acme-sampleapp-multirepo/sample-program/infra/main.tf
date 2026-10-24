locals {
  # Deliberately small, non-overlapping ranges — this is a lab VPC, not a
  # real capacity plan. /24 primary is plenty for a 1-node pool; /20s for
  # pods/services are the GKE-recommended minimum even for tiny clusters
  # because pod IPs are allocated per-node in blocks, not one at a time.
  subnets = {
    p = {
      primary_cidr  = "10.10.0.0/24"
      pods_cidr     = "10.20.0.0/20"
      services_cidr = "10.30.0.0/24"
    }
    np = {
      primary_cidr  = "10.11.0.0/24"
      pods_cidr     = "10.21.0.0/20"
      services_cidr = "10.31.0.0/24"
    }
  }

  gke_clusters = {
    p = {
      enabled      = var.enable_gke_p
      machine_type = var.gke_prod_machine_type
      node_count   = var.gke_prod_node_count
      spot         = false # prod: no spot preemption
    }
    np = {
      enabled      = var.enable_gke_np
      machine_type = var.gke_nonprod_machine_type
      node_count   = var.gke_nonprod_node_count
      spot         = true # non-prod: spot is fine, cheaper
    }
  }

  gke_clusters_enabled = { for k, v in local.gke_clusters : k => v if v.enabled }
}

module "vpc" {
  source     = "./modules/vpc"
  project_id = var.project_id
  region     = var.region
  subnets    = local.subnets
}

# for_each over a module block — same mechanic from your labs, applied for
# real here: this either creates zero, one, or two GKE clusters depending on
# which enable_gke_* flags are true, without duplicating the module call.
module "gke" {
  for_each = local.gke_clusters_enabled
  source   = "./modules/gke"

  project_id   = var.project_id
  zone         = var.zone
  name         = "sample-program-${each.key}"
  network      = module.vpc.network_self_link
  subnetwork   = module.vpc.subnets[each.key].self_link
  machine_type = each.value.machine_type
  node_count   = each.value.node_count
  spot         = each.value.spot
}

module "dns" {
  source     = "./modules/dns"
  project_id = var.project_id
  domain     = var.dns_domain
}

# ──────────────────────────────────────────────
# Publish to Consul — this is the top of the whole dependency graph. Every
# other repo's `data.consul_keys.remote_outputs.var.program` read resolves
# against this key.
# ──────────────────────────────────────────────

resource "consul_keys" "publish_outputs" {
  key {
    path = "gitlab/terraform_outputs/v2/sample-org/sample-program/default"
    value = jsonencode({
      outputs = {
        gcp = {
          us_central1 = {
            for k, v in local.gke_clusters_enabled : k => {
              gke = {
                host                   = module.gke[k].host
                cluster_ca_certificate = module.gke[k].cluster_ca_certificate
                name                   = module.gke[k].name
                project                = module.gke[k].project
              }
              dns = {
                public_zone = {
                  dns_name = module.dns.public_zone.dns_name
                }
              }
            }
          }
        }
      }
    })
  }
}
