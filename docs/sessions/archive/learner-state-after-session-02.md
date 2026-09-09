# Terraform — State

> Filled in by the Advisor persona after the initial baseline assessment (2026-08-17).
> Attach this alongside the Tutor / Editor / Advisor persona files for every future session.

---

## 1. Subject & Target

- **Subject:** Terraform (Infrastructure as Code)
- **Primary tool/language/notation:** HCL, targeting GCP + Kubernetes/Helm, using the
  `hashicorp/google`, `hashicorp/kubernetes`, `hashicorp/helm`, `hashicorp/consul`,
  `hashicorp/random`, and `scottwinkler/shell` providers
- **Target outcome:** (1) Read-and-explain fluency in a real production Terraform repo
  (multi-environment GCP/GKE/Helm deployment) well enough to discuss it credibly with
  engineering leads; (2) Standalone Terraform interview fluency (state, providers,
  meta-arguments, modules, workspaces, drift) independent of any specific repo.
- **Target date / timeline:** No fixed date — milestone-paced, not calendar-paced.
- **Time I can realistically commit:** 5–10 hrs/week.

---

## 2. My Background

- Extensive professional experience with microservices architecture — strong distributed
  systems intuition (service boundaries, dependency direction, contracts between systems).
- Strong, hands-on GCP experience specifically: IAM, service accounts, VPC/networking. This
  is significant transferable knowledge — most of the *domain* concepts in the target repo
  (Workload Identity, service accounts, IAM roles, Cloud SQL) are already understood; what's
  new is purely how Terraform expresses and orchestrates them.
- Zero prior Terraform exposure — first contact with the language and tool entirely.
- No other Infrastructure-as-Code background (no CloudFormation, Pulumi, Ansible, or CDK).
  Concepts like declarative state, plan/apply, and dependency graphs are genuinely new, not
  just unfamiliar syntax for an already-understood mental model.
- No prior structured attempts at learning Terraform (courses, tutors) — this is the first.

---

## 3. Existing Exposure / Practice History

- **Source material:** A real, non-trivial production Terraform repo (sanitized to
  `acme-sampleapp` naming for personal practice use) — a multi-environment GCP/GKE backend
  deployment: Consul-based cross-repo data sharing, Workload Identity, Cloud SQL Auth Proxy
  sidecar via IAM auth, a `shell_script` provider bridge for in-database grants, dynamic
  RBAC. This is the primary corpus being used for diagnosis and teaching.
- **2026-08-17 — Advisor baseline diagnostic (live-tested, not self-reported):**
  - Given a real ternary expression from the repo's `locals` block
    (`p_or_np = terraform.workspace == "default" ? "p" : "np"`) with `workspace = "qa"` →
    correctly answered `"np"` on first attempt, no hints. **Evidence of solid general
    expression-reading ability transferring cleanly into HCL syntax.**
  - Given the `count = local.is_review_env ? 1 : 0` pattern on `random_string.suffix` and
    asked what happens when `is_review_env = false` → answered "count 0, so empty string."
    **Partially correct** — correctly inferred the resource wouldn't meaningfully exist, but
    the actual mechanism (count turns the resource into a zero-length **list**, not an
    empty-valued single resource; referencing `[0]` on it would error without `try()`) was
    not known. Corrected in-session; this is the first logged Knowledge Gap.

---

## 4. My Own Self-Assessment (verified via live testing, not just self-report)

- Reasons fluently and quickly through unfamiliar syntax when given enough context to work
  from (confirmed via the ternary question).
- Correctly infers high-level *outcomes* of unfamiliar mechanics (count = 0 → resource
  doesn't get created) even without knowing the underlying *mechanism* (list-indexing).
- Naturally persists 30+ minutes on something hard before seeking help — high independent
  struggle tolerance. Sessions do not need to rescue early.
- Self-reported and now behaviorally confirmed reaction pattern: **"I never knew that"**
  (knowledge gap), not "I should have thought of that" (recognition gap) — this is a
  **Knowledge-Gap-dominant learner profile** for this subject. Practical implication:
  mechanics of genuinely new HCL constructs (meta-arguments, provider quirks, state
  behavior) should generally be **taught directly** rather than elicited via pure
  Socratic questioning, which works better for recognition/transfer gaps than for
  first-contact knowledge gaps. Once a mechanic has been seen once, transfer to new
  instances appears fast (per the ternary result).
- Areas expected to be hardest, per Advisor judgment (not yet self-reported by the person,
  since this is a brand-new subject): meta-arguments (`count`/`for_each`/`dynamic`) beyond
  the surface level already probed, remote state semantics, and the multi-repo
  Consul-based cross-referencing pattern (architecturally unusual, no close analog in
  typical microservices work).

---

## 5. Competency Model

(Using the standard scale unmodified — no subject-specific relabeling needed for Terraform.)

| Level | Meaning |
|---|---|
| 0 — Unknown | Little or no meaningful exposure |
| 1 — Familiar | Recognize the concept, can't reliably use it |
| 2 — Functional | Can handle straightforward, familiar-shaped cases |
| 3 — Pattern Recognition | Recognize when it applies, unprompted |
| 4 — Transfer | Can apply it to unfamiliar-but-related cases |
| 5 — Advanced | Can handle hard variations, combine with other concepts, explain why |
| 6 — Performance Ready | Reliable under realistic pressure, with clear communication |

---

## 6. Skill / Topic Matrix

```
### Topic: HCL expressions (ternaries, string interpolation)
Level: 2
Status: Functional
Last practiced: 2026-08-17
Last tested (by Advisor): 2026-08-17
Gap type: None identified yet
Recurring mistakes: None yet
Representative evidence: Correctly evaluated terraform.workspace == "default" ? "p" : "np"
for workspace="qa" cold, first attempt, no hints.
Notes: Strong transfer from general programming background — likely to move fast here.

### Topic: count meta-argument
Level: 1
Status: Pattern-dependent
Last practiced: 2026-08-17
Last tested (by Advisor): 2026-08-17
Gap type: Knowledge
Recurring mistakes: Assumed count=0 produces an empty-valued resource rather than a
zero-length list of resource instances (no [0] index exists).
Representative evidence: Answered "0 so empty string" for random_string.suffix with
count=0 — outcome-level reasoning correct, mechanism-level understanding absent.
Corrected in-session (2026-08-17): explained list-indexing behavior and the try()
pattern used in the repo specifically to guard against this.
Notes: Good candidate for a quick re-test next session to confirm retention.

### Topic: for_each meta-argument
Level: 0
Status: Unknown
Last practiced: —
Last tested: —
Gap type: Unknown (not yet probed)
Recurring mistakes: —
Representative evidence: —
Notes: Appears in iam.tf (google_project_iam_member.backend_sql_access). Not yet covered.

### Topic: providers, resources, data sources (core mechanics)
Level: 2
Status: Functional
Last practiced: 2026-08-30
Last tested (by Tutor, live/hands-on): 2026-08-30
Gap type: Knowledge (closed this session)
Recurring mistakes: Initially believed `data` blocks persist a cached value
from state even if the real underlying resource is deleted externally —
corrected: data sources re-query the live API every plan/apply and error if
the real object is gone.
Representative evidence: Live-tested (not just read) that provider-block
project/region/zone are fallback-only, overridden by any resource's own
explicit project/region/zone. Correctly predicted a 7-resource plan for
sample-program/infra unprompted, correctly excluding GKE resources based on
enable flags. Correctly reasoned (before being told) that data sources being
used for google_client_config.default makes sense specifically because
access tokens expire hourly and only a data source guarantees a fresh read.
Notes: Strong session — most reasoning was self-corrected or arrived at
independently once given the right experiment to run. One terminology slip
(said "import" meaning "depends_on") — not a conceptual gap, self-corrected.

### Topic: state, plan/apply model
Level: 2
Status: Functional
Last practiced: 2026-08-30
Last tested (by Tutor, live incident): 2026-08-30
Gap type: None outstanding
Recurring mistakes: None
Representative evidence: Correctly reasoned, unprompted, that apply commits
per-resource rather than atomically, after a real partial-apply failure
(6/7 resources succeeded, 1 failed on a Consul connection error). Correctly
predicted the re-run would show "1 to add" not "7 to add" — confirmed by
actual output. Correctly distinguished init (tooling only, no state) from
apply (the only thing that writes state) via direct observation.
Notes: This was tested via a real incident, not a contrived example —
strong evidence of genuine understanding, not memorization.

### Topic: cross-repo Consul publish/consume pattern
Level: 2
Status: Functional
Last practiced: 2026-08-30
Last tested (by Tutor, live): 2026-08-30
Gap type: None outstanding
Recurring mistakes: None
Representative evidence: Correctly diagnosed an "Invalid index" error in
backend/infra as caused by sample-program's empty gke_clusters_enabled map
(no clusters created yet), not a Terraform bug. Correctly reasoned from
microservices/distributed-systems background that a real Consul deployment
would need to be a shared, centrally-reachable service, before being told —
correctly mapped that to why `consul agent -dev` is a single-machine stand-in.
Notes: Good transfer from existing distributed-systems intuition.

### Topic: workspaces / multi-environment pattern
Level: 2
Status: Functional
Last practiced: 2026-08-30
Last tested (by Tutor, live): 2026-08-30
Gap type: None outstanding
Recurring mistakes: None
Representative evidence: Ran `terraform workspace new dev` for real (first
hands-on use, previously only read about it). Correctly predicted
local.is_review_env would evaluate true on the dev workspace, correctly
walking through both halves of the boolean expression unprompted.
Independently noticed (with Tutor framing) that static_env is a
human-maintained convention never actually cross-referenced against
terraform.workspace by the code itself.
Notes: Good real-world catch — recognizing unenforced naming conventions is
exactly the kind of thing worth flagging to a lead.

### Topic: variable precedence
Level: 3
Status: Functional
Last practiced: 2026-08-30
Last tested (by Tutor, live self-caught bug): 2026-08-30
Gap type: None outstanding — self-diagnosed with one light nudge
Recurring mistakes: None
Representative evidence: Edited a variable's default in variables.tf,
observed no effect on apply, and self-diagnosed (with minimal prompting)
that terraform.tfvars was silently overriding it. Correctly recalled the
full precedence order once taught.
Notes: This is Pattern Recognition level (3), not just Functional — the
person noticed the anomaly and started diagnosing before being told
something was wrong.

### Topic: drift / import vs recreate decision-making
Level: 2
Status: Functional
Last practiced: 2026-08-30
Last tested (by Tutor, live incident): 2026-08-30
Gap type: None outstanding
Recurring mistakes: Initial reasoning ("import vs strong state file
conflicting") was directionally right but imprecise — corrected to the real
decision criterion: resource integrity in doubt + cheap to recreate = delete
and recreate; healthy resource merely missing from state = import.
Representative evidence: Correctly chose delete-and-recreate for an orphaned,
partially-created GKE cluster from a failed apply, reasoning matched the
corrected principle once given.
Notes: Real incident, not contrived — genuinely good material.

### Topic: for_each guard propagation
Level: 1
Status: Pattern-dependent
Last practiced: 2026-08-30
Last tested (by Tutor, live incident): 2026-08-30
Gap type: Knowledge (mostly taught directly, not self-derived)
Recurring mistakes: None yet (single occurrence)
Representative evidence: Correctly diagnosed which specific for_each
iteration (prod) was failing and why, once walked through it. The actual
fix — that guarding one local doesn't protect downstream for_each loops
indexing the same unguarded structure — was taught directly rather than
self-derived; a fair Knowledge Gap given the person had not encountered this
propagation pattern before.
Notes: Worth revisiting with a fresh example next session to check for
transfer rather than recall.

### Topic: fail-fast vs graceful-degradation dependency design
Level: 2
Status: Functional
Last practiced: 2026-08-30
Last tested (by Tutor): 2026-08-30
Gap type: None outstanding (taught directly, but the underlying principle —
optional vs hard-prerequisite dependencies — was new; not something to
expect derivable from first principles without domain context)
Recurring mistakes: None
Representative evidence: N/A yet for independent application — this was a
design-comparison discussion (cloudsql.tf's try() guard vs main.tf's
unguarded app_infra line), not yet tested via the person making this choice
unprompted on new code.
Notes: Good candidate for a Gate 3 (Independent Application) task next
session — give a new optional-vs-required dependency scenario and see if
the right pattern gets chosen without prompting.

### Topic: remote state / backends / cross-repo data sharing (Consul pattern)
Level: 0
Status: Unknown
Last practiced: —
Last tested: —
Gap type: Unknown (session not yet run)
Recurring mistakes: —
Representative evidence: —
Notes: Architecturally distinctive part of the target repo; planned as Session 6.

### Topic: provider-specific resources (google_*, kubernetes_*, helm_release, shell_script)
Level: 0
Status: Unknown
Last practiced: —
Last tested: —
Gap type: Unknown (session not yet run)
Recurring mistakes: —
Representative evidence: —
Notes: To be covered resource-by-resource in context (Session 7), leveraging existing
strong GCP/IAM domain knowledge.
```

---

## 7. Known Difficult Areas

- Meta-arguments beyond the surface level (`for_each`, `dynamic`, and the list-vs-single
  semantics that `count` already exposed as a gap).
- The multi-repo Consul cross-referencing pattern — no close analog in prior microservices
  experience, expected to require deliberate teaching rather than pattern transfer.
- The `shell_script` provider bridge and the `depends_on` race-condition it exists to
  prevent — subtle, but explicitly flagged as a capstone "senior reasoning" topic worth
  extra attention for interview/lead-conversation purposes.

---

## 8. Recurring Mistakes Log

```
- [2026-08-17] Treating count=0 as "resource exists with empty value" rather than "zero
  elements in the resource's instance list" — recurred: (none yet, first occurrence)
```

---

## 9. Session History

```
### 2026-08-17 — Advisor session
Topic: Initial baseline assessment (Terraform, zero prior exposure)
What I knew going in: Strong GCP/IAM domain knowledge, strong general programming/expression
reading ability, zero Terraform-specific exposure, no other IaC background.
Gap identified: Knowledge-gap-dominant learner profile for this subject (confirmed via
self-report + live test). Specific first gap: count meta-argument's list-indexing mechanism.
What was repaired/taught/challenged: Corrected the count=0 mechanism live during the
diagnostic (list-length semantics, why try() guards random_string.suffix[0] in the repo).
Outcome: Baseline diagnostic complete. Full plan (destination, sequencing, cut list,
milestones, session-by-session plan) produced. Sanitized practice repo (acme-sampleapp)
created as the running example for all future sessions.
Hints/assistance required: light (one correction, one concept explained after an
outcome-correct-but-mechanism-incorrect answer)
Next practice recommended: Session 1 — providers, resources, data sources, state model,
using acme-sampleapp's providers.tf and google_service_account resource as first examples.

### 2026-08-30 — Tutor session
Topic: Core mechanics — provider config resolution, init/plan/apply/state,
resource vs data, partial-apply behavior, cross-repo Consul publish/consume.
What I knew going in: Strong GCP/IAM knowledge, one prior corrected gap
(count meta-argument), otherwise untested on Terraform mechanics.
Gap identified: One real misconception (data blocks persisting from state
after real-resource deletion) — corrected in-session. One terminology slip
(import vs depends_on) — self-corrected, not a real gap.
What was repaired/taught/challenged: Provider config fallback behavior
(live-tested via a controlled experiment isolating a confound the person
correctly caught — missing terraform.tfvars). Resource vs data source
semantics, corrected via live-reasoned prediction. Partial-apply/state
durability, confirmed via a real incident (Consul dev agent not running).
Cross-repo Consul dependency chain, diagnosed correctly via a real
downstream failure in backend/infra.
Outcome: sample-program/infra fully applied against real GCP
(my-devops-journey-502420) — VPC, subnets, router, NAT, DNS zone, and Consul
publish all live. GKE clusters (both p and np) enabled and about to be
applied — continues into Session 2. Session 1 notes saved to
Terraform_Session1_Notes.md for quick resupply.
Hints/assistance required: light — most conclusions were self-derived once
given the right experiment; only the "data persists after deletion"
misconception needed direct correction.
Next practice recommended: Session 2 — verify backend/infra's
kubernetes/helm provider auth chain against a real live GKE cluster once
sample-program republishes to Consul; deepen count/for_each (real for_each
usage already encountered in sample-program's module "gke" and
backend/infra/iam.tf's google_project_iam_member, worth revisiting
explicitly).

### 2026-08-30 — Tutor session (continued, Session 2)
Topic: Live GKE cluster creation against real GCP, variable precedence,
real-incident diagnosis (missing default SA, transient node pools, drift/
import-vs-recreate), workspaces hands-on, cross-repo dependency chain
debugging, guard-propagation pattern across for_each loops.
What I knew going in: Session 1's core mechanics (provider config, state,
resource/data, partial-apply). No hands-on GKE creation, workspace usage,
or variable-precedence testing yet.
Gap identified: for_each guard propagation was a genuine Knowledge Gap
(taught directly, not self-derived) — didn't know that filtering one local
doesn't automatically protect every downstream for_each indexing the same
structure. Drift/import-vs-recreate reasoning was directionally right but
imprecise on first attempt (used "state file conflict" instead of the real
criterion: resource integrity in doubt + cheap to recreate). Both corrected
in-session.
What was repaired/taught/challenged: Variable precedence (self-diagnosed
with minimal nudging — Pattern Recognition level, not just Functional).
Two real GKE/Terraform incidents (missing default Compute SA, transient
node pool config) diagnosed and fixed live, not contrived. Orphaned-resource
decision-making (import vs delete-recreate), corrected to the right
criterion. Workspaces tested hands-on for the first time (workspace show/
new), correctly predicted is_review_env behavior. Cross-repo dependency
failure traced correctly to a specific unpublished Consul key. Fail-fast vs
graceful-degradation design comparison (cloudsql.tf's guard vs main.tf's
unguarded app_infra) — new principle, taught directly, not yet independently
applied. for_each guard-propagation pattern implemented across 3 files in
infrastructure/infra (main.tf, secrets.tf, outputs.tf) after diagnosing why
guarding only main.tf's local wasn't sufficient.
Outcome: sample-program/infra's np GKE cluster created and verified live
(real host/cluster_ca_certificate/name/project values confirmed via
consul kv get). infrastructure/infra patched to gracefully skip
environments without a published cluster (Option B, chosen deliberately
over creating the p cluster) and re-applied — prediction made (2 secrets:
dev+qa) but actual apply output not yet confirmed; session paused here.
Session 2 notes saved to Terraform_Session2_Notes.md.
Hints/assistance required: light-to-moderate — most incidents were
diagnosed with one nudge or less; for_each guard propagation needed direct
teaching as a genuinely new pattern.
Next practice recommended: Session 3 — confirm the paused
infrastructure/infra apply result first. Then re-verify backend/infra plan
now that app_infra should resolve; decide on cloudsql/infra (apply for real
vs stay in mock-data mode); verify kubernetes/helm provider actually
authenticates against the live np cluster (kubectl-level check, not yet
done); continue into frontend/infra. Revisit for_each guard propagation
with a fresh example next session to test transfer, not just recall.
```

---

## 10. Readiness Gates

```
Gate 1 — Fundamentals: in progress — provider config, state, resource/data
distinction, partial-apply behavior, cross-repo Consul pattern, variable
precedence, and workspaces all demonstrated live as of 2026-08-30 (Session
2). Remaining for Gate 1: for_each/dynamic in deeper deliberate testing
(guard propagation was taught, not yet independently transferred),
Kubernetes/Helm provider auth verified against a live cluster (still
outstanding — flagged twice now as not yet directly tested).
Gate 2 — Pattern Recognition: in progress — variable precedence anomaly was
self-noticed and self-diagnosed before being told something was wrong
(genuine Pattern Recognition evidence, not just Functional-level recall).
Gate 3 — Independent Application: candidate task queued — fail-fast vs
graceful-degradation dependency design was taught via comparison, not yet
tested by giving a new scenario and checking if the right pattern gets
chosen unprompted.
Gate 4 — Transfer: not started
Gate 5 — Hard-Case Process: not started — though real (unplanned) incidents
this session (missing default SA, transient node pool, orphaned resource)
are good early evidence this gate is reachable; revisit once more core
material is solid.
Gate 6 — Performance Under Pressure: not started
Gate 7 — Communication: not started
Gate 8 — Consistency After a Gap: not started
```

---

## 11. Current Dashboard

```
Overall readiness: Gate 1 nearly complete, Gate 2 showing early evidence.
Core mechanics + variable precedence + workspaces + real incident diagnosis
all demonstrated live against real GCP. sample-program/infra fully applied
(np cluster live). infrastructure/infra patched and re-applied but result
unconfirmed — session paused mid-verification.
Strongest areas: General expression/syntax reading; reasoning about
Terraform's execution model; real-incident diagnosis (missing default SA,
orphaned resources, dependency chain tracing) — mostly self-derived with
light hinting, sometimes fully unprompted (variable precedence anomaly).
Weakest areas: for_each guard-propagation pattern (taught directly, not yet
self-derived on a new example) — needs a transfer check. Kubernetes/Helm
provider auth against a real live cluster — flagged twice now as still
outstanding, hasn't been directly tested despite the cluster now existing.
Most recent recurring mistake: None outstanding. One imprecise-but-directionally-
right reasoning attempt (drift/import-vs-recreate criterion) corrected
in-session, not yet recurring.
Next recommended focus: Session 3 — confirm the paused infrastructure/infra
apply result (predicted 2 secrets: dev+qa). Then verify backend/infra
resolves cleanly, decide on cloudsql/infra, and finally directly test
kubernetes/helm provider auth against the live np cluster — this specific
item has been deferred across two sessions now and should be prioritized.
Days/sessions until target date: N/A — milestone-paced, no fixed date.
```

---

## 12. Next Recommended Focus

- Start a Tutor session on: **confirm the paused infrastructure/infra apply
  result first** (2 secrets expected: dev+qa). Then re-verify backend/infra
  plan now that app_infra should resolve. Decide deliberately on cloudsql/infra
  (real Cloud SQL instance vs staying in mock-data mode for now — cost
  tradeoff worth discussing explicitly, not defaulting). Then — this is now
  overdue across two sessions — directly verify the kubernetes/helm provider
  actually authenticates against the live np GKE cluster (a real `kubectl get
  ns` or equivalent check), before continuing into frontend/infra. Also worth
  a fresh for_each-guard-propagation example to check transfer rather than
  recall, since Session 2's version was taught directly.
