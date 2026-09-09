---
primary_color: '#007bff'
---

# Quiz — Providers, Auth & Initialization

<!-- mkdocs-quiz intro -->
How the `google` provider gets its credentials, what `required_providers` does that a `provider` block doesn't, and why `terraform init` is the safest command in the tool. If you are debugging a "why is it using the wrong project" problem, start here.

**5 questions.** [Back to all topics](index.md)

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
init only downloads provider plugins into .terraform/ and writes .terraform.lock.hcl. It's purely tooling setup — safe to rerun anywhere, zero effect on real infrastructure or state. State only gets written once something real is created or read.
</quiz>

<!-- source: session-01 -->
<quiz>
A provider block sets `project = var.project_id`, but every resource in the module also sets its own explicit `project = var.project_id`. What happens if you delete the provider block's project line entirely?
- [ ] Every resource fails immediately with a missing-project error
- [x] Nothing changes — resource-level project overrides the provider default, so the provider's value was never actually used
- [ ] Terraform falls back to the first resource's project value for all others
- [ ] init fails because the provider is unconfigured
Provider-block project/region/zone are fallback defaults only, used exclusively by resources that don't set their own. If every resource sets its own value explicitly, the provider block's value is dead code — removing it changes nothing, live-verified via a controlled experiment.
</quiz>

<!-- source: session-01 -->
<quiz>
What's the actual difference between the `required_providers` block in a terraform{} block and a `provider "google" {}` config block?
- [ ] They're two ways of writing the same thing
- [x] required_providers controls which plugin gets downloaded during init; the provider block controls runtime configuration (auth, project, region) — a resource can still work with zero provider block config if it sets everything explicitly itself
- [ ] required_providers is optional if a provider block exists
- [ ] provider blocks are deprecated in favor of required_providers
These are two independent mechanisms. required_providers (in the terraform block) is what init actually reads to know which provider plugin to fetch — removing the provider config block entirely doesn't stop init from working, since plugin download is unrelated to runtime config. The provider block itself is only about how that plugin authenticates and what defaults it applies at apply time.
</quiz>

<!-- source: session-01 -->
<quiz>
Why is `data "google_client_config"` used to supply the GCP access token to the provider, rather than a resource or a static/stored value?
- [ ] Because resource blocks can't hold sensitive values like tokens
- [x] Because a data source re-fetches live on every plan/apply, which matters since access tokens expire hourly — a resource only updates on apply when Terraform detects drift, so it could hand out a stale, expired token
- [ ] Because provider blocks require an explicit alias to use a resource-sourced value
- [ ] There's no real difference — either approach works identically
GCP access tokens expire hourly. A resource is only re-evaluated on apply, and only then if Terraform actually detects drift — it wouldn't reliably refresh an hourly-expiring value. A data source re-queries live every single plan/apply, so it's the only mechanism that guarantees kubectl/Helm/the provider always get a fresh, valid token instead of an expired one.
</quiz>

<!-- mkdocs-quiz results -->
