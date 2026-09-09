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

<quiz>
Why is `data "google_client_config"` used to supply the GCP access token to the provider, rather than a resource or a static/stored value?
- [ ] Because resource blocks can't hold sensitive values like tokens
- [x] Because a data source re-fetches live on every plan/apply, which matters since access tokens expire hourly — a resource only updates on apply when Terraform detects drift, so it could hand out a stale, expired token
- [ ] Because provider blocks require an explicit alias to use a resource-sourced value
- [ ] There's no real difference — either approach works identically
GCP access tokens expire hourly. A resource is only re-evaluated on apply, and only then if Terraform actually detects drift — it wouldn't reliably refresh an hourly-expiring value. A data source re-queries live every single plan/apply, so it's the only mechanism that guarantees kubectl/Helm/the provider always get a fresh, valid token instead of an expired one.
</quiz>

<quiz>
Compared to a `resource` block, which of the following is true of a `data` block?
- [ ] Both are fully owned and managed (created, updated, destroyed) by Terraform
- [x] A data block is read-only — Terraform never creates, updates, or destroys the underlying object, it only reads and re-verifies it live at every plan
- [ ] A data block's value is never written to state, unlike a resource
- [ ] A data block only refreshes when -refresh=true is explicitly passed, just like a resource
A resource is fully owned by Terraform through its whole lifecycle (create/update/destroy) and tracked in state accordingly. A data block is purely read-only: Terraform never manages the underlying object's lifecycle, it just reads it — and unlike a resource, it re-verifies that read live on every plan/apply rather than trusting a cached state value.
</quiz>

<quiz>
Two `data "consul_keys"` blocks live side by side in the same file. One's path is parameterized by environment (`${local.env_key}`); the other is hardcoded to end in `/default`. The hardcoded one starts failing with an empty-string read. What's the most likely explanation?
- [ ] Consul itself is down
- [x] The hardcoded key was never actually meant to vary by environment when it was written, but the repo publishing to it only ever publishes to non-default environment paths — a genuine inconsistency between two structurally similar blocks, not a Consul or workspace problem
- [ ] The parameterized key is broken and corrupting the hardcoded one
- [ ] Terraform evaluates key blocks in a fixed, alphabetical order that can cause stale reads
That's exactly the kind of bug worth ruling other things out before finding: environment/terminal mismatch and wrong-workspace were both checked and ruled out with direct evidence first. The actual cause was found by reading the code directly — one key was parameterized, the structurally identical one beside it wasn't, and the publisher never wrote to the hardcoded path.
</quiz>

<quiz>
When a real, unexpected Terraform error appears with more than one plausible cause, what's the better debugging approach — testing hypotheses in order with direct evidence, or reading through the whole codebase first to find the bug?
- [ ] Always read the whole codebase first — testing hypotheses wastes time
- [x] Test the most likely hypotheses first with direct, falsifiable checks (e.g. `pgrep`, `workspace show`, `kv get`), and only fall back to reading code carefully once cheaper explanations are ruled out
- [ ] Hypotheses don't matter — just retry the command until it works
- [ ] Ask someone else immediately rather than debugging yourself
Real incident: environment/terminal mismatch was ruled out via `pgrep` + `consul kv get` (fast, direct). Wrong workspace was ruled out via `terraform workspace show` (fast, direct). Only once both cheap hypotheses were exhausted did reading the actual code pay off — a hardcoded, non-parameterized path sitting right next to a correctly parameterized one. Cheap checks first, code review once those are exhausted, is generally faster than either extreme alone.
</quiz>

<quiz>
A Kubernetes ServiceAccount named `my-app-sa` and a GCP IAM service account named `sa-backend-dev@project.iam.gserviceaccount.com` both exist. Are these the same identity?
- [ ] Yes — GKE automatically renames GCP service accounts to match Kubernetes ServiceAccounts
- [x] No — they're two separate identities in two separate systems, linked (if at all) via an annotation on the Kubernetes ServiceAccount, not by name matching
- [ ] Yes, as long as they're created in the same apply
- [ ] No — Workload Identity requires them to have different names by design
Workload Identity links a Kubernetes ServiceAccount to a GCP IAM service account through the `iam.gke.io/gcp-service-account` annotation on the K8s SA — not through any naming convention. Two objects can have completely unrelated names and still be correctly linked, or have similar names and NOT be linked, if the annotation is missing or wrong. Always verify the actual annotation, not the names, when confirming the binding is real.
</quiz>

<quiz>
`terraform apply` finishes with no errors and prints a Kubernetes namespace name as an output. Is that sufficient proof the namespace actually exists and is healthy on the real cluster?
- [ ] Yes — a successful apply guarantees the resource is healthy
- [x] No — apply succeeding means the API request was accepted, not that the underlying object is actually healthy; independent verification (e.g. `kubectl get ns`, `kubectl get pods`) against the real cluster is the actual proof
- [ ] Only for `data` blocks, not `resource` blocks
- [ ] Yes, but only if `-auto-approve` was used
A `helm_release` can report "created but has a failed status" — Terraform successfully told Kubernetes what to do, but that doesn't mean the workload came up healthy. `kubectl` reading the same live cluster independently is stronger evidence than trusting Terraform's own state or apply log alone.
</quiz>

<quiz>
Two separate Terraform repos both try to create a `google_secret_manager_secret_iam_member` granting the same access — one references the other repo's service-account email via cross-repo data, the other only needs data it already has locally. Which one should actually own the grant?
- [ ] Whichever repo owns the secret container, regardless of data dependencies
- [x] The one that's self-sufficient with data already available before it runs — the one requiring a "backward" reference to a repo that hasn't run yet creates an unresolvable circular ordering problem
- [ ] Both should keep the resource, for redundancy
- [ ] Whichever repo was written first
If repo A must run before repo B (by design, e.g. A publishes data B consumes), then A cannot depend on data B produces — B doesn't exist yet when A runs. The grant belongs in whichever repo needs only data that's already available in the correct apply order, even if that repo isn't the one that "owns" the underlying resource in a data-modeling sense.
</quiz>

<quiz>
A local Consul dev agent (`consul agent -dev`, in-memory only) still has old KV data describing a service account, even though that service account's Terraform state was fully destroyed and rebuilt from scratch. Why?
- [ ] Consul automatically re-validates its data against the real cloud provider
- [x] `terraform destroy` only removes real cloud resources — it has no mechanism to tell an unrelated system like Consul that the data it's holding is now stale, so a `-dev` in-memory agent can keep serving outdated data indefinitely across rebuild cycles
- [ ] The data must have been manually re-entered
- [ ] Consul data expires automatically after a fixed TTL
Nothing connects a `terraform destroy` in one repo to Consul's own data. If a Consul key was published describing a resource that's since been destroyed and never republished (e.g. because the publishing repo hasn't been re-applied yet), the old data simply sits there until it's overwritten or manually flushed. This can cause confusing errors where GCP says a referenced resource doesn't exist, even though Consul "remembers" it fine.
</quiz>

<quiz>
`terraform apply` fails on a resource with a transient network error (e.g. `TLS handshake timeout`) on a follow-up API read, right after the resource's creation call. What should you check before deciding whether to retry, import, or delete-and-recreate?
- [ ] Always retry immediately without checking anything
- [x] Check whether the resource actually exists and is healthy in the real cloud provider (e.g. `gcloud ... describe`) AND whether Terraform's state already tracks it (`terraform state list`) — a transient error on a read-back doesn't necessarily mean the underlying create failed
- [ ] Always assume the resource needs to be imported
- [ ] Always assume the resource needs to be deleted and recreated
A network timeout on a follow-up read is a different failure class from a creation that genuinely failed partway through. Checking the real resource's health directly, and whether it's already tracked in state, tells you whether this is a non-issue (just retry apply) or something that needs the import/recreate decision framework at all.
</quiz>

<quiz>
You have `roles/owner` on a GCP project, confirmed via `gcloud projects get-iam-policy`, but `kubectl get pods` still returns "Forbidden" on a freshly created GKE cluster. What's the most likely explanation?
- [ ] `roles/owner` doesn't include any GKE permissions
- [x] GKE enforces two separate authorization layers — GCP IAM and Kubernetes-native RBAC — and a brand-new cluster typically has no RBAC binding yet for your individual identity, even if your IAM role is broad; a one-time bootstrap binding (e.g. a `cluster-admin` ClusterRoleBinding for your account) is often needed
- [ ] The IAM policy needs up to 24 hours to propagate
- [ ] `kubectl` cannot read IAM policies at all, regardless of role
GCP IAM controls whether you can reach the GKE API and manage the cluster resource itself; Kubernetes RBAC (a separate, cluster-internal system) controls what you can do once you're talking to the cluster's own API server. A fresh cluster often has no RBAC binding for your personal account (Terraform-created bindings frequently target a Google Group, not individual users) — hence Forbidden despite `roles/owner`.
</quiz>

<quiz>
`kubectl get pods` fails with a Forbidden error, but IAM policy checks confirm the active account has `roles/owner` with no conditions attached. What's a likely cause worth checking before assuming the IAM policy itself is wrong?
- [ ] The cluster's control plane is down
- [x] A stale kubeconfig — if the active `gcloud` account changed since the kubeconfig entry was generated, or multiple credentialed accounts exist, `kubectl` may be authenticating as a different identity than the one just verified in IAM. Re-running `gcloud container clusters get-credentials` refreshes it against the currently active account.
- [ ] `kubectl` caches permission failures for 24 hours
- [ ] IAM policies never apply to newly created clusters
When multiple `gcloud` accounts are credentialed on one machine, kubeconfig entries can become mismatched with whichever account is "active" versus which one was active when the entry was generated. Regenerating the kubeconfig entry and re-testing with a non-destructive check like `kubectl auth can-i` isolates whether the identity itself — not the IAM policy — was the actual problem.
</quiz>

<quiz>
You change a GKE node pool's `machine_type` in Terraform (e.g. `e2-small` to `e2-standard-2`) and run `apply`. What should you expect?
- [ ] An in-place update with no disruption
- [x] Destroy-then-create of the entire node pool — a running VM's machine type can't be changed underneath it, so Terraform must replace the whole node pool, and any pods running on it will be rescheduled elsewhere or become pending until new nodes are ready
- [ ] Terraform will refuse to apply the change at all
- [ ] Only the node's labels change; the underlying VM stays the same size
Machine type is a forces-replacement attribute for node pools — Terraform destroys the old pool and creates a new one with the new size. This is a real operational consideration: on a production workload, this would cause visible disruption while nodes cycle, not just a lab inconvenience.
</quiz>

<quiz>
A GKE node shows `Capacity: cpu: 2` but `Allocatable: cpu: 940m` in `kubectl describe node`. Why is allocatable so much lower than capacity?
- [ ] It's a measurement error — they should always be equal
- [x] GKE reserves a portion of every node's CPU/memory for the kubelet and OS (a documented sliding-scale formula), and cluster-wide DaemonSets (kube-proxy, logging agents, the GKE metadata server for Workload Identity, etc.) further consume allocatable resources — neither shows up in "Capacity," only in what's actually left over for your own pods
- [ ] Allocatable only reflects the first CPU core; the second is always reserved for the OS
- [ ] The difference is caused by node autoscaling being enabled
System reservations plus DaemonSet requests can consume a large fraction of a small node's resources before any application pod is scheduled — on a 2-vCPU node, ending up with under 1 full vCPU allocatable is normal, not a misconfiguration. This is exactly why a pod's resource request that looks small on paper can still fail to schedule with "Insufficient cpu/memory."
</quiz>

<quiz>
A pod's `FailedScheduling` event says "Insufficient memory" on an `e2-small` node. You resize the node pool to `e2-medium` and the memory error disappears — but scheduling still fails, now with "Insufficient cpu" alone. Why didn't the resize fix the CPU side too?
- [ ] e2-medium has less CPU than e2-small
- [x] e2-small and e2-medium are both "shared-core" machine types with the same 2-vCPU ceiling — only memory scales between them (2GiB to 4GiB). Real additional vCPU headroom requires a different family entirely, like e2-standard-2.
- [ ] CPU requests are ignored by the scheduler, only memory requests matter
- [ ] The node pool needs a manual restart for CPU changes to take effect
Shared-core machine types (`e2-micro`/`e2-small`/`e2-medium`) all cap out at the same 2 vCPUs — stepping between them only changes memory. Fixing a CPU-allocatable shortfall specifically requires moving to a machine family that actually scales vCPU count, such as the `e2-standard-*` line.
</quiz>

<quiz>
A verification script checks GKE cluster status via `gcloud`, checks node pool existence, and separately checks `kubectl get nodes` for Ready status. Why check all three instead of just confirming the cluster status is `RUNNING`?
- [ ] They're redundant — cluster status alone is sufficient
- [x] A cluster can report `RUNNING` at the control-plane level while its node pool is missing entirely (zero compute capacity) — these are genuinely independent failure points, and checking only the top-level status would miss a real, severe problem
- [ ] `RUNNING` status only applies to node pools, not the control plane
- [ ] gcloud's status field is unreliable and should never be trusted
This happened for real: `gcloud container clusters describe` reported `RUNNING`, but the node pool had been destroyed independently (e.g. during a machine-type change or an interrupted apply), leaving zero schedulable capacity. A single high-level status check would have missed this entirely — independent checks at each layer (cluster, node pool, node readiness, namespace, workload) catch failures a single check can't.
</quiz>
<!-- mkdocs-quiz results -->