when you run `gcloud auth application-default login` creates a file at `~/.config/gcloud/application_default_credentials.json`
containing an **OAuth refresh token**

Terraform's `google` **provider** (and any Google client library) reads this file automatically if no other credentials are specified


The rule: a provider block's `project/region/zone` arguments are only a **default/fallback** — used only by resources 
that don't **explicitly** set their own project/region/zone. 

Every resource in vpc, gke, and dns modules sets project = var.project_id explicitly.

So the provider block's project = var.project_id line was never actually being consulted by anything.
Removing it changed nothing because nothing depended on it.

```shell
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
```

# The data block
the data block queries the **live GCP API**, fresh, every single `plan/apply` — it **does not** cache or remember a previous 
value from state. 
If the underlying resource is deleted outside Terraform, the very next plan would fail with something like
`Error: Failed to find resource` (or similar "not found" error), because there's nothing there to read.

|                                                  |                        `resource`                        | `data`                                                                             |
|:------------------------------------------------- |:--------------------------------------------------------:|:-----------------------------------------------------------------------------------|
| Terraform **owns** it (creates/updates/destroys) |                           Yes                            | No — read-only                                                                     |
| Tracked in **state**                             |                   Yes, full lifecycle                    | Yes, but just a cached copy of the last read, always re-verified live at plan time |
| If the real thing disappears                     | Terraform notices via `apply` and offers to recreate it  | Terraform **errors** — it has nothing to manage, only something to look up         |


a deliberate design reason google_client_config exists as a data source rather than a stored credential: your OAuth access token expires hourly, so a data source that re-fetches it live every run is exactly the right tool — a resource (which only updates on apply, and only if Terraform detects drift) would hand kubectl/Helm a stale, expired token half the time.

