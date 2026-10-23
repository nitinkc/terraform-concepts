---
primary_color: '#007bff'
---

# Quiz — GKE, Workload Identity & GCP Networking

<!-- mkdocs-quiz intro -->
Node service accounts, the `remove_default_node_pool` transient pool gotcha, Workload Identity's 4-part handshake, node capacity vs allocatable, multi-arch images, VPC peering, and IAP TCP forwarding. Reference: [§10 Production Architecture](../reference/10-architecture-multirepo-gke-and-cicd.md).

**13 questions.** [Back to all topics](index.md)

<!-- source: session-02 -->
<quiz>
GKE node pools implicitly use the default Compute Engine service account unless one is explicitly specified. What are the two independent reasons NOT to rely on it, beyond just "it might not exist yet"?
- [ ] It's deprecated in the latest provider version
- [ ] It doesn't support Workload Identity
- [x] It may not exist at all in some projects (not just a propagation delay), and even when it exists it carries broad Editor-level permissions — a real security anti-pattern
- [ ] It can only be used in a single zone
Confirmed live: `gcloud iam service-accounts list | grep compute` returned 0 items in a real project. Separately, even when it exists, its default `roles/editor` project-level grant violates least privilege. Always create a dedicated minimal-scope node SA.
</quiz>

<!-- source: session-02 -->
<quiz>
You set `remove_default_node_pool = true` on a google_container_cluster resource and give the SEPARATE google_container_node_pool resource a proper node_config with a dedicated service account. Cluster creation still fails on a missing-service-account error. Why?
- [ ] remove_default_node_pool doesn't actually work in recent provider versions
- [x] GKE still briefly creates a transient initial node pool during cluster creation, and that transient pool uses node_config on the CLUSTER resource itself, not the separate node pool resource
- [ ] The node pool must be created before the cluster, not after
- [ ] Workload Identity must be disabled first
Even with `remove_default_node_pool = true`, the GKE API requires an initial node pool to exist momentarily during cluster bootstrap. That transient pool reads `node_config` directly from `google_container_cluster`. You must set `service_account` in `node_config` on both the cluster and the separate node pool resource.
</quiz>

<!-- source: session-03 -->
<quiz>
A Kubernetes ServiceAccount named `my-app-sa` and a GCP IAM service account named `sa-backend-dev@project.iam.gserviceaccount.com` both exist. Are these the same identity?
- [ ] Yes — GKE automatically renames GCP service accounts to match Kubernetes ServiceAccounts
- [x] No — they're two separate identities in two separate systems, linked (if at all) via an annotation on the Kubernetes ServiceAccount and an IAM binding on the GCP SA, not by name matching
- [ ] Yes, as long as they're created in the same apply
- [ ] No — Workload Identity requires them to have different names by design
Workload Identity links a Kubernetes ServiceAccount to a GCP IAM service account through the `iam.gke.io/gcp-service-account` annotation on the K8s SA plus the `roles/iam.workloadIdentityUser` binding on the GSA — never through name matching.
</quiz>

<!-- source: unfiled -->
<quiz>
You have `roles/owner` on a GCP project, confirmed via `gcloud projects get-iam-policy`, but `kubectl get pods` still returns "Forbidden" on a freshly created GKE cluster. What's the most likely explanation?
- [ ] `roles/owner` doesn't include any GKE permissions
- [x] GKE enforces two separate authorization layers — GCP IAM and Kubernetes-native RBAC — and a brand-new cluster typically has no RBAC binding yet for your individual identity, even if your IAM role is broad; a bootstrap `ClusterRoleBinding` (or group binding) is needed
- [ ] The IAM policy needs up to 24 hours to propagate
- [ ] `kubectl` cannot read IAM policies at all, regardless of role
GCP IAM controls whether you can reach the GKE API and manage the cluster resource itself; Kubernetes RBAC controls what you can do inside the cluster's API server.
</quiz>

<!-- source: unfiled -->
<quiz>
`kubectl get pods` fails with a Forbidden error, but IAM policy checks confirm the active account has `roles/owner` with no conditions attached. What's a likely cause worth checking before assuming the IAM policy itself is wrong?
- [ ] The cluster's control plane is down
- [x] A stale kubeconfig — if the active `gcloud` account changed since the kubeconfig entry was generated, or multiple credentialed accounts exist, `kubectl` may be authenticating as a different identity than the one just verified in IAM. Re-running `gcloud container clusters get-credentials` refreshes it
- [ ] `kubectl` caches permission failures for 24 hours
- [ ] IAM policies never apply to newly created clusters
Regenerating kubeconfig via `gcloud container clusters get-credentials` and testing with `kubectl auth can-i` isolates whether `kubectl` was using an outdated identity.
</quiz>

<!-- source: unfiled -->
<quiz>
You change a GKE node pool's `machine_type` in Terraform (e.g. `e2-small` to `e2-standard-2`) and run `apply`. What should you expect?
- [ ] An in-place update with no disruption
- [x] Destroy-then-create of the entire node pool — a running VM's machine type can't be changed underneath it, so Terraform must replace the whole node pool, and any pods running on it will be rescheduled
- [ ] Terraform will refuse to apply the change at all
- [ ] Only the node's labels change; the underlying VM stays the same size
`machine_type` is a `ForceNew` (`# forces replacement`) attribute on `google_container_node_pool`.
</quiz>

<!-- source: unfiled -->
<quiz>
A GKE node shows `Capacity: cpu: 2` but `Allocatable: cpu: 940m` in `kubectl describe node`. Why is allocatable so much lower than capacity?
- [ ] It's a measurement error — they should always be equal
- [x] GKE reserves a portion of every node's CPU/memory for the kubelet and OS, and cluster-wide DaemonSets (kube-proxy, logging agents, the GKE metadata server for Workload Identity) further consume allocatable resources before any app pod is scheduled
- [ ] Allocatable only reflects the first CPU core; the second is always reserved for the OS
- [ ] The difference is caused by node autoscaling being enabled
System reservations plus DaemonSet requests consume a large fraction of a small node's resources before any application pod is scheduled.
</quiz>

<!-- source: unfiled -->
<quiz>
A pod's `FailedScheduling` event says "Insufficient memory" on an `e2-small` node. You resize the node pool to `e2-medium` and the memory error disappears — but scheduling still fails, now with "Insufficient cpu" alone. Why didn't the resize fix the CPU side too?
- [ ] e2-medium has less CPU than e2-small
- [x] e2-small and e2-medium are both "shared-core" machine types with the same 2-vCPU ceiling — only memory scales between them (2GiB to 4GiB). Real additional vCPU headroom requires moving to `e2-standard-2`
- [ ] CPU requests are ignored by the scheduler, only memory requests matter
- [ ] The node pool needs a manual restart for CPU changes to take effect
Shared-core machine types (`e2-micro`/`e2-small`/`e2-medium`) all cap out at 2 vCPUs; stepping between them only increases RAM.
</quiz>

<!-- source: unfiled -->
<quiz>
A GKE cluster has `workload_identity_config` set correctly. Pods still can't use Workload Identity to authenticate as their intended GCP service account. What's a likely missing piece?
- [ ] Workload Identity must also be enabled in the VPC's firewall rules
- [x] The NODE POOL also needs `workload_metadata_config { mode = "GKE_METADATA" }` — enabling Workload Identity on the cluster alone isn't sufficient, it must also be enabled on every node pool running pods that need it
- [ ] Workload Identity only works with Autopilot clusters, never Standard
- [ ] The GCP service account must be created before the GKE cluster, never after
Workload Identity requires both cluster-level `workload_identity_config` and node-pool-level `workload_metadata_config { mode = "GKE_METADATA" }`.
</quiz>

<!-- source: unfiled -->
<quiz>
Why create a GKE cluster with `remove_default_node_pool = true` plus a separate, explicit `google_container_node_pool` resource, instead of just letting the cluster's inline default node pool exist?
- [ ] It's purely cosmetic — both approaches behave identically
- [x] A node pool created inline as part of the cluster resource can't be resized, upgraded, or replaced independently without recreating the entire cluster resource
- [ ] Inline default node pools don't support Workload Identity at all
- [ ] `remove_default_node_pool` is required by GCP for all clusters created after 2023
Decoupling `google_container_node_pool` from `google_container_cluster` allows you to cycle, scale, or change machine types on node pools without destroying the control plane.
</quiz>

<!-- source: reference-10 -->
<quiz>
You launch a private GCP VM with no external IP address and try to connect using `gcloud compute ssh vm-a --tunnel-through-iap`, which fails with error `4033` / `4003`. Which firewall rule is required to make IAP SSH work?
- [ ] An ingress rule allowing TCP port 22 from `0.0.0.0/0`
- [x] An ingress rule on the VM's VPC allowing TCP port `22` from `source_ranges = ["35.235.240.0/20"]` (Google's Identity-Aware Proxy TCP forwarding range)
- [ ] An egress rule allowing UDP port 443 to the internet
- [ ] A Cloud NAT gateway on the subnet
With `--tunnel-through-iap`, TCP packets reaching the VM's internal NIC originate from Google's IAP proxy range (`35.235.240.0/20`), not from your laptop's IP. Because GCP denies all ingress by default, TCP 22 from `35.235.240.0/20` must be explicitly permitted.
</quiz>

<!-- source: reference-10 -->
<quiz>
You want two VMs in two separate GCP VPCs (`vpc-a` with subnet `10.10.0.0/24` and `vpc-b` with subnet `10.20.0.0/24`) to ping each other using VPC Peering. What must you configure in Terraform?
- [ ] One `google_compute_network_peering` resource on `vpc-a` is sufficient; firewall rules are automatically opened by peering
- [x] Two `google_compute_network_peering` resources (one `a_to_b` and one `b_to_a`, since peering requires bi-directional declaration to become `ACTIVE`) plus ingress `google_compute_firewall` rules on each VPC allowing traffic from the peer subnet's CIDR
- [ ] A Cloud Router and BGP session on both VPCs
- [ ] Subnets in both VPCs must use the exact same `10.10.0.0/24` CIDR range
VPC Peering requires non-overlapping CIDRs and explicit peering blocks in both directions (`a_to_b` and `b_to_a`) before subnet routes are exchanged automatically. And exchanging routes does not open firewall rules — ingress firewall rules for the peer CIDR are still required.
</quiz>

<!-- source: session-04 -->
<quiz>
You build a Docker image on an Apple Silicon Mac (M1/M2/M3/M4), push it to Artifact Registry, and deploy it via `helm_release` to a standard `e2-standard-2` GKE node pool. The pod fails to start with `no match for platform in manifest: not found`. Why?
- [ ] Artifact Registry does not support Docker manifests built on macOS
- [x] Apple Silicon builds `linux/arm64` images by default, while `e2-standard-2` GKE nodes are `x86_64` (`linux/amd64`) — rebuild and push with `docker build --platform linux/amd64` (or `docker buildx` multi-arch)
- [ ] The GKE node service account lacks `roles/artifactregistry.reader`
- [ ] Helm charts require container images to use SHA256 digests instead of tags
A platform manifest error means the image was pulled successfully (so IAM is fine), but the image manifest contains no `linux/amd64` layer matching the node's CPU architecture.
</quiz>

<!-- mkdocs-quiz results -->
