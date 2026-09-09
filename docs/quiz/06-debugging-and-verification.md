---
primary_color: '#007bff'
---

# Quiz — Debugging & Verification Methodology

<!-- mkdocs-quiz intro -->
Not Terraform mechanics — method. How to order hypotheses, and why a green `apply` is evidence of an API call succeeding rather than evidence of a working system.

**4 questions.** [Back to all topics](index.md)

<!-- source: unfiled -->
<quiz>
Two different Terraform learners hit the same unfamiliar syntax. One says 'I never knew that' after seeing the answer; the other says 'I should have thought of that.' What's the practical teaching implication of this difference?
- [ ] There is none — both should be taught the same way
- [x] The 'I never knew that' pattern suggests a genuine knowledge gap best closed by direct teaching, while 'I should have thought of that' suggests a recognition/transfer gap better closed by Socratic questioning
- [ ] The first learner needs more practice problems, the second needs more reading
- [ ] This only matters for beginners, not experienced engineers learning a new tool
A knowledge-gap-dominant profile means genuinely new mechanics (like HCL-specific behaviors) are more efficiently closed by direct explanation than by extended discovery-based questioning, since the person has no prior exposure to draw on. A recognition-gap-dominant profile, by contrast, benefits more from Socratic prompting since the underlying pieces are already known — the gap is in noticing when to apply them.
</quiz>

<!-- source: session-03 -->
<quiz>
When a real, unexpected Terraform error appears with more than one plausible cause, what's the better debugging approach — testing hypotheses in order with direct evidence, or reading through the whole codebase first to find the bug?
- [ ] Always read the whole codebase first — testing hypotheses wastes time
- [x] Test the most likely hypotheses first with direct, falsifiable checks (e.g. `pgrep`, `workspace show`, `kv get`), and only fall back to reading code carefully once cheaper explanations are ruled out
- [ ] Hypotheses don't matter — just retry the command until it works
- [ ] Ask someone else immediately rather than debugging yourself
Real incident: environment/terminal mismatch was ruled out via `pgrep` + `consul kv get` (fast, direct). Wrong workspace was ruled out via `terraform workspace show` (fast, direct). Only once both cheap hypotheses were exhausted did reading the actual code pay off — a hardcoded, non-parameterized path sitting right next to a correctly parameterized one. Cheap checks first, code review once those are exhausted, is generally faster than either extreme alone.
</quiz>

<!-- source: session-03 -->
<quiz>
`terraform apply` finishes with no errors and prints a Kubernetes namespace name as an output. Is that sufficient proof the namespace actually exists and is healthy on the real cluster?
- [ ] Yes — a successful apply guarantees the resource is healthy
- [x] No — apply succeeding means the API request was accepted, not that the underlying object is actually healthy; independent verification (e.g. `kubectl get ns`, `kubectl get pods`) against the real cluster is the actual proof
- [ ] Only for `data` blocks, not `resource` blocks
- [ ] Yes, but only if `-auto-approve` was used
A `helm_release` can report "created but has a failed status" — Terraform successfully told Kubernetes what to do, but that doesn't mean the workload came up healthy. `kubectl` reading the same live cluster independently is stronger evidence than trusting Terraform's own state or apply log alone.
</quiz>

<!-- source: unfiled -->
<quiz>
A verification script checks GKE cluster status via `gcloud`, checks node pool existence, and separately checks `kubectl get nodes` for Ready status. Why check all three instead of just confirming the cluster status is `RUNNING`?
- [ ] They're redundant — cluster status alone is sufficient
- [x] A cluster can report `RUNNING` at the control-plane level while its node pool is missing entirely (zero compute capacity) — these are genuinely independent failure points, and checking only the top-level status would miss a real, severe problem
- [ ] `RUNNING` status only applies to node pools, not the control plane
- [ ] gcloud's status field is unreliable and should never be trusted
This happened for real: `gcloud container clusters describe` reported `RUNNING`, but the node pool had been destroyed independently (e.g. during a machine-type change or an interrupted apply), leaving zero schedulable capacity. A single high-level status check would have missed this entirely — independent checks at each layer (cluster, node pool, node readiness, namespace, workload) catch failures a single check can't.
</quiz>

<!-- mkdocs-quiz results -->
