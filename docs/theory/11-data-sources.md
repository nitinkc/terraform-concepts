# 11 — Data sources

**Assumes:** [Outputs](10-outputs.md).

A `data` block is a **read-only query**. It fetches information about something that
exists, but does not create, update or delete it. The target can be something created
manually, by another team, or by a completely separate Terraform config and state.

```hcl
data "google_compute_network" "existing" {
  name    = "default"
  project = var.project_id
}

resource "google_compute_subnetwork" "sub" {
  network = data.google_compute_network.existing.id
}
```

## `resource` vs `data`

| | `resource` | `data` |
|:---|:---|:---|
| Lifecycle | owned (create/update/delete) | read-only |
| `terraform destroy` effect | deletes the real thing | only forgets it locally; real thing untouched |
| Refresh behaviour | refreshed to detect drift | re-queried live on every `plan`/`apply` |
| Tracked in state | yes, full lifecycle | yes, but only as a cached copy of the last read |
| If the real thing disappears | Terraform offers to recreate it | Terraform **errors** — nothing to manage, only something to look up |

**Rule of thumb:** if this config should be responsible for the resource's lifecycle →
`resource`. If it only needs to *read* something owned elsewhere → `data`.

## Data sources are queried live, every time

A `data` block hits the provider API fresh on every single `plan`/`apply`. It does **not**
serve a remembered value from state. Delete the underlying resource outside Terraform and
the very next plan fails with a not-found error rather than quietly returning a stale
value.

That has a consequence worth planning for: **every data source is a plan-time dependency
on an external system being up.** If the source (a Consul cluster, another project's API)
is unreachable, the query fails and the plan fails. Terraform does not fall back to a last
known good value.

Escape hatch:

```bash
terraform plan -refresh=false     # skip live refresh, trust state's cached values
```

Useful in an outage. Not a routine practice — you are now planning against possibly stale
reality.

## Why `google_client_config` is a data source, not a stored credential

```hcl
data "google_client_config" "default" {}

provider "kubernetes" {
  host  = "https://${module.gke.endpoint}"
  token = data.google_client_config.default.access_token
}
```

A GCP OAuth access token expires hourly. A data source that re-fetches it live on every run
is exactly the right tool. A `resource` would only update on `apply`, and only if Terraform
detected drift — so it would hand `kubectl`/Helm a stale, expired token much of the time.
**The expiry window of the value is what decides `data` vs `resource` here**, not
convenience.

The same reasoning applies to reading a secret from Secret Manager or Vault via `data` at
apply time: the value is fetched when needed and never written into the config.

## The ownership boundary

Splitting ownership across configs — repo A owns the database as a `resource`, repo B reads
its connection details via a `data` block — lets several independent consumers share
information about one owned thing without any of them holding write permissions on it. That
pattern is big enough to get its own page:
[Cross-config composition](15-cross-config-composition.md).

## Key takeaway

`resource` = "I own this." `data` = "someone else owns this and I need to look at it." The
second one buys you a live value and costs you a hard runtime dependency on whatever you're
querying.

---

Labs: [Data sources](../basics/06-data-sources.md),
[Lab 7](../gcp/02-lab-notes.md#lab-7-data-sources) ·
Quiz: [Resources, state & drift](../quiz/02-resources-state-and-drift.md) ·
Next: [Modules](12-modules.md)
