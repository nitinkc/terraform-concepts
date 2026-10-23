---
primary_color: '#007bff'
---

# Quiz — Providers, Auth, Versions & Backends

<!-- mkdocs-quiz intro -->
How the `google` provider authenticates, `required_providers` vs `provider {}`, version constraints (`~>`), lock files, provider aliasing, and backend initialization. Reference: [§1 Execution Model & Providers](../reference/01-execution-model-and-providers.md) and [§2 State & Backends](../reference/02-resources-state-and-backends.md).

**10 questions.** [Back to all topics](index.md)

<!-- source: session-01 -->
<quiz>
What does `gcloud auth application-default login` actually create, and where?
- [ ] A short-lived access token stored in an environment variable
- [x] A refresh token written to ~/.config/gcloud/application_default_credentials.json
- [ ] A service account key file in the current directory
- [ ] Nothing persistent — it re-authenticates on every terraform command
It writes an OAuth refresh token to that file. Terraform's google provider and any Google client library read it automatically. The derived access token expires hourly, but the refresh token doesn't — you authenticate once and forget about it until you explicitly revoke it.
</quiz>

<!-- source: session-01 -->
<quiz>
Does `terraform init` create or touch terraform.tfstate?
- [ ] Yes, it initializes an empty state file
- [x] No — state is only written by the first real apply or refresh
- [ ] Only if a backend block is configured
- [ ] Only for local backends, not remote ones
init only downloads provider plugins into .terraform/, configures the backend, and writes .terraform.lock.hcl. It is purely tooling setup — safe to rerun anywhere, zero effect on real infrastructure or state.
</quiz>

<!-- source: session-01 -->
<quiz>
A provider block sets `project = var.project_id`, but every resource in the module also sets its own explicit `project = var.project_id`. What happens if you delete the provider block's project line entirely?
- [ ] Every resource fails immediately with a missing-project error
- [x] Nothing changes — resource-level project overrides the provider default, so the provider's value was never actually used
- [ ] Terraform falls back to the first resource's project value for all others
- [ ] init fails because the provider is unconfigured
Provider-block project/region/zone are fallback defaults only, used exclusively by resources that don't set their own. If every resource sets its own value explicitly, the provider block's value is dead code — removing it changes nothing.
</quiz>

<!-- source: session-01 -->
<quiz>
What's the actual difference between the `required_providers` block in a terraform{} block and a `provider "google" {}` config block?
- [ ] They're two ways of writing the same thing
- [x] required_providers controls which plugin gets downloaded during init; the provider block controls runtime configuration (auth, project, region) — a resource can still work with zero provider block config if it sets everything explicitly itself
- [ ] required_providers is optional if a provider block exists
- [ ] provider blocks are deprecated in favor of required_providers
required_providers (in the terraform block) is what init reads to know which provider plugin to fetch. The provider block itself is only about how that plugin authenticates and what defaults it applies at plan/apply time.
</quiz>

<!-- source: session-01 -->
<quiz>
Why is `data "google_client_config"` used to supply the GCP access token to downstream providers (`kubernetes`, `helm`), rather than a resource or a static/stored value?
- [ ] Because resource blocks can't hold sensitive values like tokens
- [x] Because a data source re-fetches live on every plan/apply, which matters since access tokens expire hourly — a resource only updates on apply when Terraform detects drift, so it could hand out a stale, expired token
- [ ] Because provider blocks require an explicit alias to use a resource-sourced value
- [ ] There's no real difference — either approach works identically
GCP access tokens expire hourly. A data source re-queries live on every single plan/apply, guaranteeing that kubectl/Helm always receive a fresh, valid token instead of a cached expired one.
</quiz>

<!-- source: reference-01 -->
<quiz>
What is the exact difference between the version constraints `version = "~> 2.4.1"` and `version = "~> 2.4"`?
- [ ] They are identical — trailing zeros and patch numbers are ignored by `~>`
- [x] `~> 2.4.1` allows only patch updates (`>= 2.4.1, < 2.5.0`), whereas `~> 2.4` allows minor version updates (`>= 2.4.0, < 3.0.0`)
- [ ] `~> 2.4` allows major version updates (`>= 2.4.0`), whereas `~> 2.4.1` allows minor updates
- [ ] `~> 2.4.1` pins strictly to `2.4.1` with no updates allowed
With the pessimistic constraint operator (`~>`), only the right-most specified version component is allowed to increment. Misplacing the last digit is how unexpected minor or major provider upgrades slip in during `init -upgrade`.
</quiz>

<!-- source: reference-01 -->
<quiz>
Why should `.terraform.lock.hcl` be committed to Git in production repositories while `.terraform/` is gitignored, and why must a teammate still run `terraform init` after cloning?
- [ ] `.terraform.lock.hcl` contains the compiled provider binaries compressed as text
- [x] `.terraform.lock.hcl` records the exact chosen provider versions and cryptographic checksums, while `.terraform/` holds OS/CPU-specific provider binaries that each machine must download for its own architecture via `terraform init`
- [ ] `.terraform.lock.hcl` stores encrypted state locks for GCS
- [ ] Plain `terraform init` ignores `.terraform.lock.hcl` unless `-upgrade` is passed
The version constraint in `.tf` expresses acceptable range (intent), while `.terraform.lock.hcl` records the exact resolved version (fact). Plain `terraform init` honors the lock file and downloads the matching binary for the caller's OS into `.terraform/`; only `terraform init -upgrade` moves the locked version.
</quiz>

<!-- source: reference-01 -->
<quiz>
You define a secondary provider block `provider "google" { alias = "us_east" ... }` in your root module and call a child module `module "east_storage" { source = "./modules/storage" }`. How does the child module use the `us_east` provider?
- [ ] Child modules automatically inherit all aliased providers if their resource names include the alias
- [ ] You declare a matching `provider "google" { region = "us-east1" }` block inside the child module
- [x] You must explicitly pass `providers = { google = google.us_east }` inside the `module "east_storage"` block; child modules only inherit the default (unaliased) provider automatically
- [ ] You pass the provider as a string variable `var.provider = "google.us_east"`
Child modules never inherit aliased providers implicitly and should never contain their own hardcoded `provider {}` configuration blocks (which makes them non-reusable). Passing `providers = { google = google.us_east }` maps the child module's default `google` reference to the parent's `google.us_east` configuration.
</quiz>

<!-- source: reference-02 -->
<quiz>
Why can't a Terraform configuration create the GCS bucket defined in its own `backend "gcs" {}` block, and what happens if you use a partial `backend "gcs" {}` block and forget to pass `-backend-config` during `terraform init`?
- [ ] GCS buckets cannot be created by Terraform at all; omitting `-backend-config` falls back to local state
- [x] `terraform init` connects to the backend before evaluating any resource blocks (chicken-and-egg); omitting `-backend-config` on a partial `gcs` backend causes Terraform to query GCS with an empty bucket name, failing with a misleading `404 bucket doesn't exist` error
- [ ] `backend "gcs"` automatically creates the bucket if you pass `-auto-approve` to `init`
- [ ] You can solve it by referencing `bucket = google_storage_bucket.state.name` inside the `backend` block
`init` sets up state storage before the resource graph is ever built, and `backend {}` blocks cannot interpolate variables or resource attributes. And when `-backend-config="bucket=..."` is omitted, Terraform sends an empty bucket string to the GCS API, returning `storage: bucket doesn't exist ... 404` rather than a syntax error.
</quiz>

<!-- source: reference-05 -->
<quiz>
`terraform apply` on a `google_storage_bucket` fails with `Error 412: constraints/storage.uniformBucketLevelAccess`. What does this error mean and what is the fix?
- [ ] The Terraform Google provider version is incompatible with the GCS API
- [x] A GCP Organization Policy forbids legacy object ACLs, while the `google_storage_bucket` resource defaults `uniform_bucket_level_access` to `false` — set `uniform_bucket_level_access = true` explicitly on the resource
- [ ] Your ADC credentials expired mid-apply
- [ ] The bucket name is already taken globally by another GCP project
Provider defaults do not always match your organization's security guardrails. An `Error 412` mentioning `constraints/...` is a GCP Organization Policy rejection, fixed by explicitly setting the required attribute (`uniform_bucket_level_access = true`) in HCL.
</quiz>

<!-- mkdocs-quiz results -->
