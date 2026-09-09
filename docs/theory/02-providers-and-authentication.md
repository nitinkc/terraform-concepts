# 2 — Providers and authentication

**Assumes:** [What Terraform is](01-what-terraform-is.md).

A **provider** is a plugin that translates HCL into actual cloud API calls. Terraform core
knows nothing about GCP/AWS/etc. — all provider-specific logic (how to create a service
account, what fields are valid) lives in the provider binary, e.g. `hashicorp/google`.

## Two blocks, two jobs

| Block | Purpose | Read during |
|:---|:---|:---|
| `required_providers` (inside `terraform {}`) | *Which* plugin, *where* from, *which* version | `terraform init` |
| `provider "google" {}` | *How* to configure it — project, region, credentials | `plan` / `apply` |

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}
```

`required_providers` is mandatory for every provider you use. A `provider {}` block is only
needed when the provider actually needs configuring — the `local` and `random` providers
take none, so their blocks are empty or absent, but they still have to be *declared*. The
lab version of this distinction is [Provider versions](../basics/11-provider-versions.md).

## Provider-block `project`/`region`/`zone` are defaults, not settings

They are a fallback, consulted **only** by resources that don't set their own. If every
resource in a config sets `project = var.project_id` itself, the provider block's `project`
line is dead code — removing it changes nothing, because nothing was ever reading it.
Worth knowing before you go looking for a bug in the provider block.

## Authentication: Application Default Credentials

```bash
gcloud auth application-default login
```

This writes `~/.config/gcloud/application_default_credentials.json`, containing an OAuth
**refresh token**. Terraform's `google` provider — and any Google client library — reads
that file automatically when no other credentials are specified. The derived *access*
token expires hourly; the *refresh* token does not, so you authenticate once and forget
about it until you explicitly revoke it.

Precedence for the `google` provider, highest first:

| Source | Typical use |
|---|---|
| `credentials` argument in the `provider` block | explicit key file, rarely the right answer |
| `GOOGLE_CREDENTIALS` / `GOOGLE_APPLICATION_CREDENTIALS` env var | CI runners |
| Application Default Credentials file | local development |
| Attached service account (GCE/GKE/Cloud Build metadata server) | workload running in GCP |

The last row is what makes [CI-based execution](16-gitops-and-cicd.md) work without any key
material on disk.

## Aliasing: more than one configuration of the same provider

One `provider` block per provider is the default case. When you need two — two regions, two
projects, a primary and a DR cluster — add an `alias` and route resources explicitly.

```hcl
provider "google" {
  alias   = "us_east"
  project = var.project_id
  region  = "us-east1"
}

resource "google_storage_bucket" "east" {
  provider = google.us_east          # without this line, the default block is used
  name     = "${local.name_prefix}-east"
  location = "US-EAST1"
}
```

Three rules worth memorising:

1. The block **without** an alias is the default; any resource that doesn't say `provider =`
   gets it.
2. `provider = google.us_east` is not a string — it's a reference, so no quotes.
3. A `module` doesn't inherit aliased providers automatically. You pass them in with a
   `providers = { google = google.us_east }` map on the module call.

The GCP run-through is [Lab 14](../gcp/02-lab-notes.md#lab-14-provider-aliasing-multi-region-multi-project).

## Key takeaway

`required_providers` is resolved once at `init`; provider configuration is read on every
`plan`. Credentials are ambient by design — nothing about *which* identity you're using
appears in the HCL, which is exactly why "it works on my laptop and fails in CI" is
usually an ADC-versus-service-account difference and not a code difference.

---

Labs: [Provider versions](../basics/11-provider-versions.md),
[Core GCP root](../gcp/01-core-root.md) ·
Quiz: [Providers & auth](../quiz/01-providers-and-auth.md) ·
Next: [terraform init and version constraints](03-init-and-version-constraints.md)
