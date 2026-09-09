---
primary_color: '#007bff'
---

# Quiz — GKE, Kubernetes & Workload Identity

<!-- mkdocs-quiz intro -->
Node service accounts, the two-identities-linked-by-annotation model of Workload Identity, and the node-sizing arithmetic that decides whether a pod can actually be scheduled. Most of these came from real failures, not from reading docs.

**8 questions.** [Back to all topics](index.md)

<!-- source: session-02 -->
<quiz>
GKE node pools implicitly use the default Compute Engine service account unless one is explicitly specified. What are the two independent reasons NOT to rely on it, beyond just "it might not exist yet"?
- [ ] It's deprecated in the latest provider version
- [ ] It doesn't support Workload Identity
- [x] It may not exist at all in some projects (not just a propagation delay), and even when it exists it carries broad Editor-level permissions — a real security anti-pattern
- [ ] It can only be used in a single zone
Confirmed live: `gcloud iam service-accounts list | grep compute` returned 0 items in a real project — not a timing issue, the SA never existed. Separately, even when it does exist, its broad project-level permissions are a genuine anti-pattern for every node to trust by default. A dedicated, minimal-scope node service account fixes both problems at once.
</quiz>

<!-- source: session-02 -->
<quiz>
You set `remove_default_node_pool = true` on a google_container_cluster resource and give the SEPARATE google_container_node_pool resource a proper node_config with a dedicated service account. Cluster creation still fails on a missing-service-account error. Why?
- [ ] remove_default_node_pool doesn't actually work in recent provider versions
- [x] GKE still briefly creates a transient initial node pool during cluster creation, and that transient pool uses node_config on the CLUSTER resource itself, not the separate node pool resource
- [ ] The node pool must be created before the cluster, not after
- [ ] Workload Identity must be disabled first
Even with remove_default_node_pool = true, the GKE API requires an initial node pool to exist momentarily during cluster creation (Terraform deletes it right after). That transient pool reads node_config from google_container_cluster directly. Without a matching node_config there too, it falls back to the same missing default SA — same error, different resource, easy to miss on a first encounter.
</quiz>

<!-- source: session-03 -->
<quiz>
A Kubernetes ServiceAccount named `my-app-sa` and a GCP IAM service account named `sa-backend-dev@project.iam.gserviceaccount.com` both exist. Are these the same identity?
- [ ] Yes — GKE automatically renames GCP service accounts to match Kubernetes ServiceAccounts
- [x] No — they're two separate identities in two separate systems, linked (if at all) via an annotation on the Kubernetes ServiceAccount, not by name matching
- [ ] Yes, as long as they're created in the same apply
- [ ] No — Workload Identity requires them to have different names by design
Workload Identity links a Kubernetes ServiceAccount to a GCP IAM service account through the `iam.gke.io/gcp-service-account` annotation on the K8s SA — not through any naming convention. Two objects can have completely unrelated names and still be correctly linked, or have similar names and NOT be linked, if the annotation is missing or wrong. Always verify the actual annotation, not the names, when confirming the binding is real.
</quiz>

<!-- source: unfiled -->
<quiz>
You have `roles/owner` on a GCP project, confirmed via `gcloud projects get-iam-policy`, but `kubectl get pods` still returns "Forbidden" on a freshly created GKE cluster. What's the most likely explanation?
- [ ] `roles/owner` doesn't include any GKE permissions
- [x] GKE enforces two separate authorization layers — GCP IAM and Kubernetes-native RBAC — and a brand-new cluster typically has no RBAC binding yet for your individual identity, even if your IAM role is broad; a one-time bootstrap binding (e.g. a `cluster-admin` ClusterRoleBinding for your account) is often needed
- [ ] The IAM policy needs up to 24 hours to propagate
- [ ] `kubectl` cannot read IAM policies at all, regardless of role
GCP IAM controls whether you can reach the GKE API and manage the cluster resource itself; Kubernetes RBAC (a separate, cluster-internal system) controls what you can do once you're talking to the cluster's own API server. A fresh cluster often has no RBAC binding for your personal account (Terraform-created bindings frequently target a Google Group, not individual users) — hence Forbidden despite `roles/owner`.
</quiz>

<!-- source: unfiled -->
<quiz>
`kubectl get pods` fails with a Forbidden error, but IAM policy checks confirm the active account has `roles/owner` with no conditions attached. What's a likely cause worth checking before assuming the IAM policy itself is wrong?
- [ ] The cluster's control plane is down
- [x] A stale kubeconfig — if the active `gcloud` account changed since the kubeconfig entry was generated, or multiple credentialed accounts exist, `kubectl` may be authenticating as a different identity than the one just verified in IAM. Re-running `gcloud container clusters get-credentials` refreshes it against the currently active account.
- [ ] `kubectl` caches permission failures for 24 hours
- [ ] IAM policies never apply to newly created clusters
When multiple `gcloud` accounts are credentialed on one machine, kubeconfig entries can become mismatched with whichever account is "active" versus which one was active when the entry was generated. Regenerating the kubeconfig entry and re-testing with a non-destructive check like `kubectl auth can-i` isolates whether the identity itself — not the IAM policy — was the actual problem.
</quiz>

<!-- source: unfiled -->
<quiz>
You change a GKE node pool's `machine_type` in Terraform (e.g. `e2-small` to `e2-standard-2`) and run `apply`. What should you expect?
- [ ] An in-place update with no disruption
- [x] Destroy-then-create of the entire node pool — a running VM's machine type can't be changed underneath it, so Terraform must replace the whole node pool, and any pods running on it will be rescheduled elsewhere or become pending until new nodes are ready
- [ ] Terraform will refuse to apply the change at all
- [ ] Only the node's labels change; the underlying VM stays the same size
Machine type is a forces-replacement attribute for node pools — Terraform destroys the old pool and creates a new one with the new size. This is a real operational consideration: on a production workload, this would cause visible disruption while nodes cycle, not just a lab inconvenience.
</quiz>

<!-- source: unfiled -->
<quiz>
A GKE node shows `Capacity: cpu: 2` but `Allocatable: cpu: 940m` in `kubectl describe node`. Why is allocatable so much lower than capacity?
- [ ] It's a measurement error — they should always be equal
- [x] GKE reserves a portion of every node's CPU/memory for the kubelet and OS (a documented sliding-scale formula), and cluster-wide DaemonSets (kube-proxy, logging agents, the GKE metadata server for Workload Identity, etc.) further consume allocatable resources — neither shows up in "Capacity," only in what's actually left over for your own pods
- [ ] Allocatable only reflects the first CPU core; the second is always reserved for the OS
- [ ] The difference is caused by node autoscaling being enabled
System reservations plus DaemonSet requests can consume a large fraction of a small node's resources before any application pod is scheduled — on a 2-vCPU node, ending up with under 1 full vCPU allocatable is normal, not a misconfiguration. This is exactly why a pod's resource request that looks small on paper can still fail to schedule with "Insufficient cpu/memory."
</quiz>

<!-- source: unfiled -->
<quiz>
A pod's `FailedScheduling` event says "Insufficient memory" on an `e2-small` node. You resize the node pool to `e2-medium` and the memory error disappears — but scheduling still fails, now with "Insufficient cpu" alone. Why didn't the resize fix the CPU side too?
- [ ] e2-medium has less CPU than e2-small
- [x] e2-small and e2-medium are both "shared-core" machine types with the same 2-vCPU ceiling — only memory scales between them (2GiB to 4GiB). Real additional vCPU headroom requires a different family entirely, like e2-standard-2.
- [ ] CPU requests are ignored by the scheduler, only memory requests matter
- [ ] The node pool needs a manual restart for CPU changes to take effect
Shared-core machine types (`e2-micro`/`e2-small`/`e2-medium`) all cap out at the same 2 vCPUs — stepping between them only changes memory. Fixing a CPU-allocatable shortfall specifically requires moving to a machine family that actually scales vCPU count, such as the `e2-standard-*` line.
</quiz>

<!-- mkdocs-quiz results -->
