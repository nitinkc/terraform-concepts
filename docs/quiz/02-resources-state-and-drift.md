---
primary_color: '#007bff'
---

# Quiz — Resources, Data Sources, State, Lifecycle & Surgery

<!-- mkdocs-quiz intro -->
The apply model — what Terraform owns vs reads, non-atomic applies, missing state vs missing resources, `lifecycle` meta-arguments, state surgery (`mv`, `rm`, `import`), and state security. Reference: [§2 State & Backends](../reference/02-resources-state-and-backends.md), [§3 Identity & Lifecycle](../reference/03-identity-lifecycle-and-change.md), [§8 Data Sources](../reference/08-data-sources-outputs-and-modules.md), and [§9 State Surgery](../reference/09-state-surgery-drift-and-workspaces.md).

**12 questions.** [Back to all topics](index.md)

<!-- source: session-01 -->
<quiz>
If a `data` block references a real cloud resource, and someone deletes that resource outside Terraform entirely, what happens on the next `terraform plan`?
- [ ] The data block returns its last cached value from state
- [ ] Terraform silently recreates the resource
- [x] The plan errors — data sources re-query the live API every run and have nothing to manage
- [ ] Nothing — data blocks don't get re-evaluated unless -refresh is passed
Unlike resources, data sources are read-only and always re-fetch live on every plan/apply. If the real object is gone, there's nothing to read, so it errors rather than returning a stale value.
</quiz>

<!-- source: session-01 -->
<quiz>
During `terraform apply`, 6 of 7 planned resources succeed and 1 fails with an unrelated error (e.g. a network timeout on an external API call). What state are the 6 successful resources in afterward?
- [ ] Rolled back — apply is all-or-nothing
- [x] Real and durably written to state — apply commits per-resource, not atomically
- [ ] Marked as tainted and destroyed on the next apply
- [ ] Left in a pending state until manually confirmed
Terraform apply is NOT transactional. Each resource writes to state as it individually succeeds. A re-run after a partial failure only needs to create the remainder ("1 to add", not 7).
</quiz>

<!-- source: session-01 -->
<quiz>
Compared to a `resource` block, which of the following is true of a `data` block?
- [ ] Both are fully owned and managed (created, updated, destroyed) by Terraform
- [x] A data block is read-only — Terraform never creates, updates, or destroys the underlying object, it only reads and re-verifies it live at every plan
- [ ] A data block's value is never written to state, unlike a resource
- [ ] A data block only refreshes when -refresh=true is explicitly passed, just like a resource
A resource is fully owned by Terraform through its whole lifecycle (create/update/destroy). A data block is purely read-only: `terraform destroy` never touches the real object a `data` block reads.
</quiz>

<!-- source: session-02 -->
<quiz>
A `terraform apply` fails partway through creating a cloud resource (e.g. a GKE cluster) due to an unrelated error. The next apply attempt fails with 'Already exists' because the resource is now real in the cloud but absent from Terraform state. What's the right general decision criterion for import vs delete-and-recreate?
- [ ] Always import — recreating loses history
- [ ] Always delete and recreate — imports are unreliable
- [x] Import if the resource is healthy and just untracked; delete-and-recreate if its integrity is in doubt (e.g. a failed partial creation) and nothing irreplaceable would be lost
- [ ] It depends only on whether the resource costs money
`import` is right for a healthy resource that is simply missing from state. A resource whose creation failed partway through may be half-built — importing it risks fighting drift indefinitely. If it holds no irreplaceable data, delete-and-recreate is cleaner.
</quiz>

<!-- source: session-02 -->
<quiz>
`terraform apply` fails on a resource with a transient network error (e.g. `TLS handshake timeout`) on a follow-up API read, right after the resource's creation call. What should you check before deciding whether to retry, import, or delete-and-recreate?
- [ ] Always retry immediately without checking anything
- [x] Check whether the resource actually exists and is healthy in the real cloud provider (e.g. `gcloud ... describe`) AND whether Terraform's state already tracks it (`terraform state list`) — a transient error on a read-back doesn't necessarily mean the underlying create failed
- [ ] Always assume the resource needs to be imported
- [ ] Always assume the resource needs to be deleted and recreated
Checking the real resource's health directly, and whether it's already tracked in `terraform state list`, tells you whether you can simply re-run `apply` or whether you need `import`/recreation.
</quiz>

<!-- source: reference-02 -->
<quiz>
You delete `terraform.tfstate` (or run `terraform state rm`) while the real resource still exists, and then run `terraform apply`. How does the behavior differ between `local_file` and `google_service_account`?
- [ ] Both fail with an "AlreadyExists" error
- [ ] Both silently adopt the existing resource back into state
- [x] Both plan to create the resource fresh because Terraform never scans for orphans — on apply, `local_file` silently overwrites the existing file on disk, while `google_service_account` fails loudly with `409 AlreadyExists` from the GCP API
- [ ] `local_file` fails with a permission error while `google_service_account` overwrites the SA
State loss gives Terraform amnesia. Whether a subsequent `apply` fails safely or causes silent data loss is entirely provider-dependent: cloud APIs enforce uniqueness on identifiers like `account_id`, whereas file-based providers silently clobber existing files.
</quiz>

<!-- source: reference-09 -->
<quiz>
A GCS bucket was created manually in `us-central1`. You write a `resource "google_storage_bucket" "b"` block in HCL with `location = "US"` and run `terraform import google_storage_bucket.b my-bucket`. What happens?
- [ ] `terraform import` fails immediately because `location = "US"` does not match `us-central1`
- [ ] `terraform import` automatically updates your `.tf` file to change `"US"` to `"us-central1"`
- [x] `terraform import` succeeds (it only binds the cloud ID into state without validating HCL attributes), and the very next `terraform plan` proposes **destroying and recreating** the bucket because `location` mismatches and is a ForceNew field
- [ ] Terraform ignores the `location` mismatch permanently for imported resources
`import` only writes the resource into `terraform.tfstate`. It does not generate or validate your HCL attributes against reality. Always run `terraform plan` immediately after `import` and align your HCL to reach a zero-diff plan before applying.
</quiz>

<!-- source: reference-03 -->
<quiz>
You rename `resource "google_service_account" "gsa"` to `resource "google_service_account" "backend_sa"` in a shared Git repository. What is the difference between fixing this with `terraform state mv` vs. adding a `moved {}` block in HCL?
- [ ] `moved {}` destroys and recreates the resource, whereas `state mv` does not
- [x] Both update the address in state without touching the real GCP service account, but a `moved {}` block is committed to Git, peer-reviewed in the PR, and executes automatically during CI/teammates' next plan/apply
- [ ] `terraform state mv` works on modules, whereas `moved {}` only works on `local_file`
- [ ] `moved {}` requires `terraform import` to be run first
Resource identity is the HCL address. Both mechanisms migrate the state address cleanly without recreation, but `moved { from = ... to = ... }` (Terraform 1.1+) turns an imperative local state surgery command into declarative, version-controlled code.
</quiz>

<!-- source: reference-03 -->
<quiz>
A `google_service_account` has `lifecycle { prevent_destroy = true }`. You do NOT run `terraform destroy`; instead, you change its `account_id` attribute in `main.tf` and run `terraform plan`. What happens?
- [ ] The plan succeeds and updates `account_id` in place
- [ ] The plan succeeds and replaces the service account because `prevent_destroy` only blocks the `terraform destroy` CLI command
- [x] The plan fails with an error — changing `account_id` forces replacement (`-/+`), which includes a destroy step that `prevent_destroy` blocks
- [ ] Terraform ignores the `account_id` change automatically
Because `account_id` cannot be mutated in place via the GCP IAM API, changing it requires a `ForceNew` replacement (destroy + create). `prevent_destroy = true` rejects *any* plan that would destroy the resource, including replacements.
</quiz>

<!-- source: reference-03 -->
<quiz>
When is `lifecycle { ignore_changes = [...] }` the right architectural choice, and what happens if you write `ignore_changes = [tags]` on a `local_file` resource?
- [ ] Use it whenever a `plan` diff looks confusing; `ignore_changes = [tags]` is silently ignored if the attribute doesn't exist
- [x] Use it when an external system legitimately owns a specific field (e.g., an autoscaler changing node count, external label automation, or a `timestamp()` attribute); naming a non-existent attribute like `tags` on `local_file` fails validation immediately
- [ ] Use it instead of `prevent_destroy` to stop resource deletion; `tags` must be quoted as `"tags"`
- [ ] `ignore_changes` only works on `data` sources, not `resource` blocks
`ignore_changes` takes bare attribute identifiers validated against the provider schema (which is why `tags` on `local_file` errors). Architecturally, use it only to prevent two systems from fighting over a field that is intentionally mutated outside Terraform.
</quiz>

<!-- source: reference-03 -->
<quiz>
Why can adding `lifecycle { create_before_destroy = true }` to a `google_service_account` with a static `account_id = "acme-backend"` cause replacement to fail?
- [ ] `create_before_destroy` is not supported by the `google` provider
- [x] Because GCP requires `account_id` to be unique within the project — Terraform tries to create the replacement service account with the exact same `account_id` while the old one still exists, failing with `409 AlreadyExists`
- [ ] `create_before_destroy` deletes the state file before creating the new resource
- [ ] `create_before_destroy` only works when `count` is greater than 1
`create_before_destroy` provisions the new instance before deleting the old one. If the resource has a fixed, globally/project-unique identifier (like a bucket `name` or SA `account_id`) with no random suffix, both instances cannot coexist simultaneously.
</quiz>

<!-- source: reference-02 -->
<quiz>
You want developers to be able to run `terraform plan` from their laptops against the production GCS state backend, but you do NOT want them to be able to read production secrets stored in `terraform.tfstate`. Which GCP IAM role accomplishes this?
- [ ] `roles/storage.objectViewer` with an IAM condition restricting `terraform state pull`
- [ ] Marking all secrets `sensitive = true` in HCL prevents `plan` callers from reading them
- [x] None — `terraform plan` requires read access to the state file in GCS, and anyone who can read the state object can read every plaintext secret inside it; execution must be moved to CI/CD to keep state off laptops
- [ ] Using `data "terraform_remote_state"` hides secrets from `plan`
There is no IAM boundary between "can run `terraform plan`" and "can read `terraform.tfstate`". Because Terraform must read the entire state file to compute a diff—and state stores all values in plaintext regardless of `sensitive = true`—anyone who can run `plan` locally can inspect all secrets in that state.
</quiz>

<!-- mkdocs-quiz results -->
