---
primary_color: '#007bff'
---

# Interactive Verification Quiz

<!-- mkdocs-quiz intro -->
Please test your knowledge below before continuing.


<quiz>
What does `gcloud auth application-default login` actually create, and where?
- [ ] A short-lived access token stored in an environment variable
- [x] A refresh token written to ~/.config/gcloud/application_default_credentials.json
- [ ] A service account key file in the current directory
- [ ] Nothing persistent — it re-authenticates on every terraform command
It writes an OAuth refresh token to that file. Terraform's google provider and any Google client library read it automatically. The derived access token expires hourly, but the refresh token doesn't — you authenticate once and forget about it until you explicitly revoke it.
</quiz>

<quiz>
Does `terraform init` create or touch terraform.tfstate?
- [ ] Yes, it initializes an empty state file
- [x] No — state is only written by the first real apply or refresh
- [ ] Only if a backend block is configured
- [ ] Only for local backends, not remote ones
init only downloads provider plugins into .terraform/ and writes .terraform.lock.hcl. It's purely tooling setup — safe to rerun anywhere, zero effect on real infrastructure or state. State only gets written once something real is created or read.
</quiz>

<quiz>
A provider block sets `project = var.project_id`, but every resource in the module also sets its own explicit `project = var.project_id`. What happens if you delete the provider block's project line entirely?
- [ ] Every resource fails immediately with a missing-project error
- [x] Nothing changes — resource-level project overrides the provider default, so the provider's value was never actually used
- [ ] Terraform falls back to the first resource's project value for all others
- [ ] init fails because the provider is unconfigured
Provider-block project/region/zone are fallback defaults only, used exclusively by resources that don't set their own. If every resource sets its own value explicitly, the provider block's value is dead code — removing it changes nothing, live-verified via a controlled experiment.
</quiz>

<quiz>
If a `data` block references a real cloud resource, and someone deletes that resource outside Terraform entirely, what happens on the next `terraform plan`?
- [ ] The data block returns its last cached value from state
- [ ] Terraform silently recreates the resource
- [x] The plan errors — data sources re-query the live API every run and have nothing to manage
- [ ] Nothing — data blocks don't get re-evaluated unless -refresh is passed
Unlike resources, data sources are read-only and always re-fetch live on every plan/apply. If the real object is gone, there's nothing to read, so it errors rather than returning a stale value. This is also why data "google_client_config" is used for auth tokens specifically — access tokens expire hourly, and only a data source guarantees a fresh read every run.
</quiz>

<quiz>
During `terraform apply`, 6 of 7 planned resources succeed and 1 fails with an unrelated error (e.g. a network timeout on an external API call). What state are the 6 successful resources in afterward?
- [ ] Rolled back — apply is all-or-nothing
- [x] Real and durably written to state — apply commits per-resource, not atomically
- [ ] Marked as tainted and destroyed on the next apply
- [ ] Left in a pending state until manually confirmed
Terraform apply is NOT transactional. Each resource writes to state as it individually succeeds. A re-run after a partial failure only needs to create the remainder — direct, observable proof of this: a 7-resource apply that failed on resource #7 only showed "1 to add" on retry, not 7.
</quiz>

<quiz>
In a multi-repo Terraform setup using Consul KV instead of terraform_remote_state for cross-repo data sharing, what's the main advantage of the Consul approach?
- [ ] It's faster at plan time
- [ ] It avoids needing a backend at all
- [x] It's a deliberate, minimal publish/subscribe contract instead of exposing another repo's entire state file
- [ ] It supports encryption while remote_state doesn't
terraform_remote_state creates a hard coupling to another repo's ENTIRE state file, including internal details it never meant to expose. A Consul KV write is closer to a service publishing an API contract — deliberate, versioned, and minimal. The tradeoff: nothing catches a field-name typo at plan time the way a typed module output would.
</quiz>

<quiz>
You edit a variable's `default` value in variables.tf, but terraform.tfvars already sets that same variable. Which value does Terraform actually use?
- [ ] The new default — defaults always win for clarity
- [ ] Whichever was set most recently by file modification time
- [x] The terraform.tfvars value — it sits higher in the precedence order than defaults
- [ ] Terraform errors out on the conflict
Precedence low to high: default in variables.tf < terraform.tfvars < *.auto.tfvars < -var-file < -var flag < TF_VAR_* env vars. A .tfvars file silently overrides an edited default — a genuinely common real-world gotcha that can waste real debugging time if you don't know the order.
</quiz>

<quiz>
GKE node pools implicitly use the default Compute Engine service account unless one is explicitly specified. What are the two independent reasons NOT to rely on it, beyond just "it might not exist yet"?
- [ ] It's deprecated in the latest provider version
- [ ] It doesn't support Workload Identity
- [x] It may not exist at all in some projects (not just a propagation delay), and even when it exists it carries broad Editor-level permissions — a real security anti-pattern
- [ ] It can only be used in a single zone
Confirmed live: `gcloud iam service-accounts list | grep compute` returned 0 items in a real project — not a timing issue, the SA never existed. Separately, even when it does exist, its broad project-level permissions are a genuine anti-pattern for every node to trust by default. A dedicated, minimal-scope node service account fixes both problems at once.
</quiz>

<quiz>
You set `remove_default_node_pool = true` on a google_container_cluster resource and give the SEPARATE google_container_node_pool resource a proper node_config with a dedicated service account. Cluster creation still fails on a missing-service-account error. Why?
- [ ] remove_default_node_pool doesn't actually work in recent provider versions
- [x] GKE still briefly creates a transient initial node pool during cluster creation, and that transient pool uses node_config on the CLUSTER resource itself, not the separate node pool resource
- [ ] The node pool must be created before the cluster, not after
- [ ] Workload Identity must be disabled first
Even with remove_default_node_pool = true, the GKE API requires an initial node pool to exist momentarily during cluster creation (Terraform deletes it right after). That transient pool reads node_config from google_container_cluster directly. Without a matching node_config there too, it falls back to the same missing default SA — same error, different resource, easy to miss on a first encounter.
</quiz>

<quiz>
A `terraform apply` fails partway through creating a cloud resource (e.g. a GKE cluster) due to an unrelated error. The next apply attempt fails with 'Already exists' because the resource is now real in the cloud but absent from Terraform state. What's the right general decision criterion for import vs delete-and-recreate?
- [ ] Always import — recreating loses history
- [ ] Always delete and recreate — imports are unreliable
- [x] Import if the resource is healthy and just untracked; delete-and-recreate if its integrity is in doubt (e.g. a failed partial creation) and nothing irreplaceable would be lost
- [ ] It depends only on whether the resource costs money
import is right for a healthy resource that's simply missing from state. But a resource whose creation failed partway through may be in an inconsistent, half-built state — importing it risks fighting drift indefinitely. The deciding factor: does this resource hold anything you'd lose by deleting it? A minutes-old, broken, empty lab cluster has nothing to preserve, so delete-and-recreate beats reconciling.
</quiz>

<quiz>
A repo has `local.static_envs = ["dev", "qa"]` and separately a `var.static_env` boolean that controls review-environment behavior. Does Terraform automatically ensure these two stay consistent (e.g. that running on the 'dev' workspace automatically sets static_env = true)?
- [ ] Yes, workspace names are automatically cross-referenced against any list containing them
- [x] No — static_envs is purely descriptive and never actually checked against terraform.workspace; static_env is a separate, manually-set value with no automatic connection
- [ ] Only if the list is named exactly 'static_envs'
- [ ] Yes, but only in Terraform 1.7+
A real, easy-to-miss design gap: static_envs existing as a list of strings doesn't mean anything checks terraform.workspace against it. Whoever applies the dev/qa workspaces is expected to remember to also set static_env = true manually. Forget it, and 'dev' silently gets treated as an ephemeral review environment. Naming conventions in Terraform are never automatically enforced unless code explicitly wires them together.
</quiz>

<quiz>
One local value is wrapped in try(..., "") with a null-check before use (feeding a graceful mock-data fallback). A different local value in the same repo calls jsondecode directly with no guard, and fails loudly if the upstream data is missing. Is the unguarded one necessarily worse code?
- [ ] Yes — every external data read should always be guarded defensively
- [x] No — it depends on whether the dependency is genuinely optional (with a real fallback) or a hard prerequisite the system can't meaningfully run without
- [ ] Yes, because unguarded code always indicates the original author made a mistake
- [ ] No, guards should never be used in production Terraform
In this case: an optional database dependency had a real mock-data fallback, so a guard made sense there. An SSO/auth secret had no meaningful fallback — failing fast and loud when it's missing is the CORRECT design, not a shortcut. Blanket-wrapping every read in try() would hide a real prerequisite failure behind a confusing downstream error instead of surfacing it immediately.
</quiz>

<quiz>
A local value filters out entries whose upstream dependency doesn't exist yet, e.g. `{ for k, v in x : k => v if condition }`. Two other resources elsewhere in the same repo still do `for_each = toset(local.full_unfiltered_list)` and then index into the now-filtered map directly. What happens?
- [ ] Terraform automatically applies the same filter to every for_each in the repo
- [ ] Nothing — filtering one local protects the whole repo
- [x] The same 'invalid index' error just resurfaces in those other resources — a guard only protects what it directly wraps
- [ ] Terraform throws a compile-time warning about the mismatch
This is a real, easy-to-miss pattern: guarding a local's own computation does nothing for a separate for_each elsewhere that iterates the ORIGINAL unfiltered list and indexes into the filtered map. Every downstream consumer needs either the same filtered key-set for its own for_each, or its own independent guard — otherwise the failure just moves one file downstream, and looks like a brand new bug rather than the same root cause.
</quiz>

<quiz>
A resource has `count = local.some_condition ? 1 : 0`. When the condition is false, what actually happens to that resource?
- [ ] It's created with all attributes set to empty/null values
- [x] It doesn't get created at all — count turns the resource into a zero-length LIST of instances, and index [0] doesn't exist
- [ ] It's created but marked disabled
- [ ] Terraform throws a plan-time error unless the condition is always true
count = 0 means zero instances exist — not that one instance exists with empty values. count also implicitly turns the resource into a list, even with only one possible instance, so referencing resource[0] when count=0 would error unless wrapped in try(). This is exactly why try(resource[0].result, "") shows up in real code guarding count-conditional resources.
</quiz>

<quiz>
A module block uses for_each over a map filtered down to only enabled entries: `for_each = { for k, v in x : k => v if v.enabled }`. If both entries in the map are disabled, what does `for_each`-over-modules actually do?
- [ ] Errors, since for_each over modules requires at least one entry
- [x] Creates zero instances of that module — an empty map means an empty for_each, no error
- [ ] Falls back to creating exactly one instance with default values
- [ ] Requires a separate count = 0 guard in addition to for_each
for_each over an empty map/set simply creates nothing — no error, no fallback. This is exactly how a GKE-cluster module block can safely default to creating zero clusters when both environment-enable flags are false, letting terraform plan succeed cleanly without any resources being created.
</quiz>

<quiz>
In a dependency chain repo-A → repo-B → repo-C (each publishing data the next consumes via Consul), repo-C fails with an 'Invalid index' error trying to read a key that's supposed to come from repo-A. What's the most likely root cause?
- [ ] repo-C's own code has a bug
- [x] repo-A hasn't been applied yet, or was applied without the specific resource that populates that key
- [ ] Consul itself is down
- [ ] repo-B is missing a required provider
An 'Invalid index' on a specific nested key (not a connection error) means the JSON structure exists but is missing that particular branch — almost always because the actual upstream publisher (repo-A here) either hasn't been applied at all, or was applied with a condition (like a feature flag) that skipped creating the resource that would have populated it. Worth checking the specific missing key against what the publisher actually created before assuming Consul or the reading repo is broken.
</quiz>

<quiz>
Two different Terraform learners hit the same unfamiliar syntax. One says 'I never knew that' after seeing the answer; the other says 'I should have thought of that.' What's the practical teaching implication of this difference?
- [ ] There is none — both should be taught the same way
- [x] The 'I never knew that' pattern suggests a genuine knowledge gap best closed by direct teaching, while 'I should have thought of that' suggests a recognition/transfer gap better closed by Socratic questioning
- [ ] The first learner needs more practice problems, the second needs more reading
- [ ] This only matters for beginners, not experienced engineers learning a new tool
A knowledge-gap-dominant profile means genuinely new mechanics (like HCL-specific behaviors) are more efficiently closed by direct explanation than by extended discovery-based questioning, since the person has no prior exposure to draw on. A recognition-gap-dominant profile, by contrast, benefits more from Socratic prompting since the underlying pieces are already known — the gap is in noticing when to apply them.
</quiz>

<quiz>
What's the actual difference between the `required_providers` block in a terraform{} block and a `provider "google" {}` config block?
- [ ] They're two ways of writing the same thing
- [x] required_providers controls which plugin gets downloaded during init; the provider block controls runtime configuration (auth, project, region) — a resource can still work with zero provider block config if it sets everything explicitly itself
- [ ] required_providers is optional if a provider block exists
- [ ] provider blocks are deprecated in favor of required_providers
These are two independent mechanisms. required_providers (in the terraform block) is what init actually reads to know which provider plugin to fetch — removing the provider config block entirely doesn't stop init from working, since plugin download is unrelated to runtime config. The provider block itself is only about how that plugin authenticates and what defaults it applies at apply time.
</quiz>


<!-- mkdocs-quiz results -->

