---
primary_color: '#007bff'
---

# Quiz — Resources, Data Sources, State & Drift

<!-- mkdocs-quiz intro -->
The apply model — what Terraform owns versus what it merely reads, what survives a failed apply, and how to decide between `import` and delete-and-recreate when reality and state disagree.

**5 questions.** [Back to all topics](index.md)

<!-- source: session-01 -->
<quiz>
If a `data` block references a real cloud resource, and someone deletes that resource outside Terraform entirely, what happens on the next `terraform plan`?
- [ ] The data block returns its last cached value from state
- [ ] Terraform silently recreates the resource
- [x] The plan errors — data sources re-query the live API every run and have nothing to manage
- [ ] Nothing — data blocks don't get re-evaluated unless -refresh is passed
Unlike resources, data sources are read-only and always re-fetch live on every plan/apply. If the real object is gone, there's nothing to read, so it errors rather than returning a stale value. This is also why data "google_client_config" is used for auth tokens specifically — access tokens expire hourly, and only a data source guarantees a fresh read every run.
</quiz>

<!-- source: session-01 -->
<quiz>
During `terraform apply`, 6 of 7 planned resources succeed and 1 fails with an unrelated error (e.g. a network timeout on an external API call). What state are the 6 successful resources in afterward?
- [ ] Rolled back — apply is all-or-nothing
- [x] Real and durably written to state — apply commits per-resource, not atomically
- [ ] Marked as tainted and destroyed on the next apply
- [ ] Left in a pending state until manually confirmed
Terraform apply is NOT transactional. Each resource writes to state as it individually succeeds. A re-run after a partial failure only needs to create the remainder — direct, observable proof of this: a 7-resource apply that failed on resource #7 only showed "1 to add" on retry, not 7.
</quiz>

<!-- source: session-01 -->
<quiz>
Compared to a `resource` block, which of the following is true of a `data` block?
- [ ] Both are fully owned and managed (created, updated, destroyed) by Terraform
- [x] A data block is read-only — Terraform never creates, updates, or destroys the underlying object, it only reads and re-verifies it live at every plan
- [ ] A data block's value is never written to state, unlike a resource
- [ ] A data block only refreshes when -refresh=true is explicitly passed, just like a resource
A resource is fully owned by Terraform through its whole lifecycle (create/update/destroy) and tracked in state accordingly. A data block is purely read-only: Terraform never manages the underlying object's lifecycle, it just reads it — and unlike a resource, it re-verifies that read live on every plan/apply rather than trusting a cached state value.
</quiz>

<!-- source: session-02 -->
<quiz>
A `terraform apply` fails partway through creating a cloud resource (e.g. a GKE cluster) due to an unrelated error. The next apply attempt fails with 'Already exists' because the resource is now real in the cloud but absent from Terraform state. What's the right general decision criterion for import vs delete-and-recreate?
- [ ] Always import — recreating loses history
- [ ] Always delete and recreate — imports are unreliable
- [x] Import if the resource is healthy and just untracked; delete-and-recreate if its integrity is in doubt (e.g. a failed partial creation) and nothing irreplaceable would be lost
- [ ] It depends only on whether the resource costs money
import is right for a healthy resource that's simply missing from state. But a resource whose creation failed partway through may be in an inconsistent, half-built state — importing it risks fighting drift indefinitely. The deciding factor: does this resource hold anything you'd lose by deleting it? A minutes-old, broken, empty lab cluster has nothing to preserve, so delete-and-recreate beats reconciling.
</quiz>

<!-- source: session-02 -->
<quiz>
`terraform apply` fails on a resource with a transient network error (e.g. `TLS handshake timeout`) on a follow-up API read, right after the resource's creation call. What should you check before deciding whether to retry, import, or delete-and-recreate?
- [ ] Always retry immediately without checking anything
- [x] Check whether the resource actually exists and is healthy in the real cloud provider (e.g. `gcloud ... describe`) AND whether Terraform's state already tracks it (`terraform state list`) — a transient error on a read-back doesn't necessarily mean the underlying create failed
- [ ] Always assume the resource needs to be imported
- [ ] Always assume the resource needs to be deleted and recreated
A network timeout on a follow-up read is a different failure class from a creation that genuinely failed partway through. Checking the real resource's health directly, and whether it's already tracked in state, tells you whether this is a non-issue (just retry apply) or something that needs the import/recreate decision framework at all.
</quiz>

<!-- mkdocs-quiz results -->
