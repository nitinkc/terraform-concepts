---
primary_color: '#007bff'
---

# Quiz — Debugging, Recovery & Verification Methodology

<!-- mkdocs-quiz intro -->
How to order hypotheses by cost of falsification, why an empty `terraform.tfstate` file is not proof of an unapplied or healthy root, and why a green `terraform apply` is never a substitute for independent verification. Reference: [§9 State Surgery & Recovery](../reference/09-state-surgery-drift-and-workspaces.md) and [§10 Production Architecture](../reference/10-architecture-multirepo-gke-and-cicd.md).

**6 questions.** [Back to all topics](index.md)

<!-- source: unfiled -->
<quiz>
Two different Terraform learners hit the same unfamiliar syntax. One says 'I never knew that' after seeing the answer; the other says 'I should have thought of that.' What's the practical teaching implication of this difference?
- [ ] There is none — both should be taught the same way
- [x] The 'I never knew that' pattern suggests a genuine knowledge gap best closed by direct teaching, while 'I should have thought of that' suggests a recognition/transfer gap better closed by Socratic questioning
- [ ] The first learner needs more practice problems, the second needs more reading
- [ ] This only matters for beginners, not experienced engineers learning a new tool
A knowledge gap (unseen mechanic) is closed by direct explanation; a recognition gap (known mechanic not connected to the current symptom) is closed by targeted diagnostic questions.
</quiz>

<!-- source: session-03 -->
<quiz>
When a real, unexpected Terraform error appears with more than one plausible cause, what's the better debugging approach — testing hypotheses in order with direct evidence, or reading through the whole codebase first to find the bug?
- [ ] Always read the whole codebase first — testing hypotheses wastes time
- [x] Test the most likely, cheapest-to-falsify hypotheses first with direct commands (e.g. `pgrep`, `workspace show`, `kv get`), and only fall back to reading code line-by-line once environmental/state explanations are ruled out
- [ ] Hypotheses don't matter — just retry the command until it works
- [ ] Ask someone else immediately rather than debugging yourself
Real incident: environment/terminal mismatch was ruled out via `pgrep` + `consul kv get` in seconds. Wrong workspace was ruled out via `terraform workspace show` in seconds. Only once both fast checks passed did code inspection immediately isolate a hardcoded `/default` Consul path.
</quiz>

<!-- source: session-03 -->
<quiz>
`terraform apply` finishes with no errors and prints a Kubernetes namespace name as an output. Is that sufficient proof the namespace and workload actually exist and are healthy on the real cluster?
- [ ] Yes — a successful apply guarantees the resource is healthy
- [x] No — apply succeeding means the API request was accepted, not that the underlying workload came up healthy; independent verification (`kubectl get ns`, `kubectl get pods`, `kubectl get sa -o jsonpath='{.metadata.annotations}'`) against the live cluster is the actual proof
- [ ] Only for `data` blocks, not `resource` blocks
- [ ] Yes, but only if `-auto-approve` was used
A `helm_release` or Kubernetes resource can be accepted by the API server while pods are stuck in `ImagePullBackOff`, `CrashLoopBackOff`, or `Pending` (insufficient CPU). Always verify with an independent tool (`kubectl`, `gcloud`, `consul`).
</quiz>

<!-- source: unfiled -->
<quiz>
A verification script checks GKE cluster status via `gcloud`, checks node pool existence, and separately checks `kubectl get nodes` for Ready status. Why check all three instead of just confirming the cluster status is `RUNNING`?
- [ ] They're redundant — cluster status alone is sufficient
- [x] A cluster can report `RUNNING` at the control-plane level while its node pool is missing entirely or its Spot nodes are not yet `Ready` — checking each layer independently catches failures a top-level status check misses
- [ ] `RUNNING` status only applies to node pools, not the control plane
- [ ] gcloud's status field is unreliable and should never be trusted
`gcloud container clusters describe` reports `RUNNING` as soon as the control plane is up, even if 0 worker nodes exist or Spot nodes are still bootstrapping.
</quiz>

<!-- source: session-04 -->
<quiz>
A recovery script checks `[ -f terraform.tfstate ]` to guard against accidentally bootstrapping over existing infrastructure. Why did that check fail to detect that `infrastructure/infra` and `backend/infra` owned zero resources?
- [ ] `terraform init` deletes `terraform.tfstate` whenever it runs
- [x] A `terraform.tfstate` file still exists on disk after `terraform destroy` or failed runs, containing an empty `"resources": []` array — scripts must check `terraform state list` (non-empty resource count) AND reconcile against live cloud APIs before deciding whether state is populated
- [ ] `terraform.tfstate` is a binary file that `-f` cannot test
- [ ] Workspace state files are stored in `/tmp` by default
File existence (`-f terraform.tfstate`) does not equal resource ownership. After a destroy or partial initialization, the state file exists as valid JSON with zero tracked resources. Always inspect `terraform state list`.
</quiz>

<!-- source: session-04 -->
<quiz>
An automation script starts `consul agent -dev &` in the background and immediately runs `terraform apply` on a root containing `resource "consul_keys"`. The apply intermittently fails with `connection refused` on `127.0.0.1:8500`. What is the architectural lesson?
- [ ] `consul agent -dev` requires `sudo` to bind port 8500
- [x] Launching a local process asynchronously does not mean its HTTP API and Raft leader election are ready — automation must first verify the binary is installed (`command -v consul`) and poll a health/readiness endpoint (`/v1/status/leader`) before invoking Terraform
- [ ] Terraform cannot talk to `127.0.0.1` without an explicit `depends_on`
- [ ] `consul_keys` can only be used with remote backends
Any provider dependency started by a wrapper script (Consul, Vault, Cloud SQL Proxy, port-forwards) must have an explicit readiness loop before `terraform plan` or `apply` executes.
</quiz>

<!-- mkdocs-quiz results -->
