# Stage 4 — The acme-sampleapp sandbox

This is where the isolated exercises stop and the real thing starts. Everything in
[Stage 2](../basics/index.md) and [Stage 3](../gcp/index.md) teaches one mechanic at a time
in a directory you can delete without consequence. The sandbox is five independent
Terraform roots that depend on each other through a Consul contract, deploy Helm charts
onto a real GKE cluster, and cost real money while they're up.

The single most important difference: **no root here can be understood in isolation.**
`backend/infra` reads values that `cloudsql/infra`, `infrastructure/infra`, and
`sample-program/infra` published. Break one and you learn what a dependency graph
actually feels like.

## Before you touch it

| | |
|---|---|
| Source of truth for layout | [`acme-sampleapp-multirepo-sandbox-elaborate/README.md`](https://github.com/nitinkc/terraform-concepts/blob/main/acme-sampleapp-multirepo-sandbox-elaborate/README.md) |
| Source of truth for running it | [`RUNBOOK.md`](runbook.md) — apply order, Consul dev agent, teardown |
| Session-by-session history | [Session log](../sessions/index.md) |
| Concept → file lookup | [Concept index](../theory/concept-index.md) |

!!! warning "This one bills"
    Stages 1–3 are free or nearly so. The sandbox stands up a GKE cluster, Secret Manager
    secrets, and optionally a Cloud SQL instance. Read the cost section at the end of the
    RUNBOOK before enabling anything, and run `./destroy-all.sh` when you pause.

## The one pattern to read first

`sample-program/infra/main.tf` is the highest-value file in the sandbox, because it is the
`for_each`-over-modules pattern from the labs applied for real:

```hcl
module "vpc" {
  source     = "./modules/vpc"
  project_id = var.project_id
  region     = var.region
  subnets    = local.subnets
}

# for_each over a module block — same mechanic from the labs, applied for
# real here: this creates zero, one, or two GKE clusters depending on
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
```

Two things worth sitting with before moving on:

1. **Zero is a legal outcome.** If both enable flags are false, `local.gke_clusters_enabled`
   is an empty map and `module.gke` produces nothing at all — no error, no partial cluster.
   Everything downstream then has to cope with an empty map, which is exactly the
   guard-propagation bug that cost a real session's debugging time. See
   [Session 2](../sessions/session-02.md).
2. **The filtering happens in `locals`, not in the module.** The module doesn't know it's
   conditional. That separation is why the same module is reusable, and why the guard has
   to be re-applied by every *consumer* of the filtered map rather than once at the source.

## Reference — sandbox README

--8<-- "acme-sampleapp-multirepo-sandbox-elaborate/README.md:body"
