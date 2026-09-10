---
primary_color: '#007bff'
---

# Quiz — Multi-Repo & Consul Contracts

<!-- mkdocs-quiz intro -->
Why the sandbox publishes through Consul KV instead of `terraform_remote_state`, what breaks when an upstream repo hasn't published yet, and who should own a grant when the resource and the dependency point in opposite directions.

**6 questions.** [Back to all topics](index.md)

<!-- source: session-01 -->
<quiz>
In a multi-repo Terraform setup using Consul KV instead of terraform_remote_state for cross-repo data sharing, what's the main advantage of the Consul approach?
- [ ] It's faster at plan time
- [ ] It avoids needing a backend at all
- [x] It's a deliberate, minimal publish/subscribe contract instead of exposing another repo's entire state file
- [ ] It supports encryption while remote_state doesn't
terraform_remote_state creates a hard coupling to another repo's ENTIRE state file, including internal details it never meant to expose. A Consul KV write is closer to a service publishing an API contract — deliberate, versioned, and minimal. The tradeoff: nothing catches a field-name typo at plan time the way a typed module output would.
</quiz>

<!-- source: session-01 -->
<quiz>
In a dependency chain repo-A → repo-B → repo-C (each publishing data the next consumes via Consul), repo-C fails with an 'Invalid index' error trying to read a key that's supposed to come from repo-A. What's the most likely root cause?
- [ ] repo-C's own code has a bug
- [x] repo-A hasn't been applied yet, or was applied without the specific resource that populates that key
- [ ] Consul itself is down
- [ ] repo-B is missing a required provider
An 'Invalid index' on a specific nested key (not a connection error) means the JSON structure exists but is missing that particular branch — almost always because the actual upstream publisher (repo-A here) either hasn't been applied at all, or was applied with a condition (like a feature flag) that skipped creating the resource that would have populated it. Worth checking the specific missing key against what the publisher actually created before assuming Consul or the reading repo is broken.
</quiz>

<!-- source: session-03 -->
<quiz>
Two `data "consul_keys"` blocks live side by side in the same file. One's path is parameterized by environment (`${local.env_key}`); the other is hardcoded to end in `/default`. The hardcoded one starts failing with an empty-string read. What's the most likely explanation?
- [ ] Consul itself is down
- [x] The hardcoded key was never actually meant to vary by environment when it was written, but the repo publishing to it only ever publishes to non-default environment paths — a genuine inconsistency between two structurally similar blocks, not a Consul or workspace problem
- [ ] The parameterized key is broken and corrupting the hardcoded one
- [ ] Terraform evaluates key blocks in a fixed, alphabetical order that can cause stale reads
That's exactly the kind of bug worth ruling other things out before finding: environment/terminal mismatch and wrong-workspace were both checked and ruled out with direct evidence first. The actual cause was found by reading the code directly — one key was parameterized, the structurally identical one beside it wasn't, and the publisher never wrote to the hardcoded path.
</quiz>

<!-- source: unfiled -->
<quiz>
Two separate Terraform repos both try to create a `google_secret_manager_secret_iam_member` granting the same access — one references the other repo's service-account email via cross-repo data, the other only needs data it already has locally. Which one should actually own the grant?
- [ ] Whichever repo owns the secret container, regardless of data dependencies
- [x] The one that's self-sufficient with data already available before it runs — the one requiring a "backward" reference to a repo that hasn't run yet creates an unresolvable circular ordering problem
- [ ] Both should keep the resource, for redundancy
- [ ] Whichever repo was written first
If repo A must run before repo B (by design, e.g. A publishes data B consumes), then A cannot depend on data B produces — B doesn't exist yet when A runs. The grant belongs in whichever repo needs only data that's already available in the correct apply order, even if that repo isn't the one that "owns" the underlying resource in a data-modeling sense.
</quiz>

<!-- source: session-03 -->
<quiz>
A local Consul dev agent (`consul agent -dev`, in-memory only) still has old KV data describing a service account, even though that service account's Terraform state was fully destroyed and rebuilt from scratch. Why?
- [ ] Consul automatically re-validates its data against the real cloud provider
- [x] `terraform destroy` only removes real cloud resources — it has no mechanism to tell an unrelated system like Consul that the data it's holding is now stale, so a `-dev` in-memory agent can keep serving outdated data indefinitely across rebuild cycles
- [ ] The data must have been manually re-entered
- [ ] Consul data expires automatically after a fixed TTL
Nothing connects a `terraform destroy` in one repo to Consul's own data. If a Consul key was published describing a resource that's since been destroyed and never republished (e.g. because the publishing repo hasn't been re-applied yet), the old data simply sits there until it's overwritten or manually flushed. This can cause confusing errors where GCP says a referenced resource doesn't exist, even though Consul "remembers" it fine.
</quiz>

<!-- source: unfiled -->
<quiz>
A real production Consul deployment and the `consul agent -dev` used in this sandbox both work with identical Terraform HCL. What's actually different between them?
- [ ] Nothing meaningful — dev mode is just a rebranded production mode
- [x] Production Consul is a shared, centrally-reachable service (its own cluster, a stable network address every CI/CD runner can reach, real ACL tokens for auth) that many independent pipelines read/write concurrently; `-dev` mode is single-machine, in-memory, and has zero access control — never appropriate outside a local laptop
- [ ] Production Consul requires a different provider block syntax
- [ ] `-dev` mode persists data to disk while production mode doesn't
The provider and resource blocks are mechanically identical either way — only WHERE `CONSUL_HTTP_ADDR` points, and whether real ACL tokens protect it, differ. This is why `-dev` mode data can vanish or go stale with no warning: it's an intentionally minimal stand-in for a real shared service, not a smaller version of the same guarantees.
</quiz>

<!-- mkdocs-quiz results -->
