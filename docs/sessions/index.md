# Session log

Hands-on tutoring sessions against a real GCP project, using the
[acme-sampleapp sandbox](../sandbox/index.md). These are notes, not documentation — they
record what was attempted in order, including the attempts that were wrong. That ordering
is the point: the [theory pages](../theory/index.md) tells you how Terraform behaves, and
these tell you which of those behaviours actually bit.

| # | Date | Focus | Real incidents |
|---|---|---|---|
| [1](session-01.md) | 2026-08-30 | Provider config, `init`/`plan`/`apply`/state, `resource` vs `data`, partial-apply behaviour, cross-repo Consul publish/consume | 1 |
| [2](session-02.md) | 2026-08-30 | Live GKE cluster creation, variable precedence, workspaces, guard propagation | 5 |
| [3](session-03.md) | 2026-08-31 | Full destroy/rebuild from zero, multi-hypothesis debugging, Kubernetes/Helm provider auth verified via `kubectl` | 3 |

## What each session established

**Session 1** — the execution model. That `init` is pure tooling and never touches state;
that a provider block's `project`/`region`/`zone` are fallbacks nothing reads if every
resource sets its own; that `apply` commits per-resource rather than transactionally; and
that a `data` block re-queries live every run instead of serving a cached value. Corrected
one belief outright: data blocks do *not* persist from state when the real thing is gone.

**Session 2** — the day everything broke usefully. Five diagnosed incidents: a default
Compute Engine service account that never existed, the transient node pool that
`remove_default_node_pool` creates anyway, an orphaned resource after a partial-failure
apply, a missing upstream Consul publish, and a `for_each` hitting an entry whose upstream
data didn't exist yet. The last one produced the **guard-propagation** rule — a guard only
protects what it directly wraps, so every downstream consumer of a filtered value needs its
own. Session 2 paused mid-verification with an unseen `apply` output.

**Session 3** — resumed after a ~5 hour gap and a full teardown, which turned into an
accidental test of whether Session 2's fixes generalised on a completely fresh apply (they
did). The session's core was a three-hypothesis debugging sequence — terminal/env mismatch,
then workspace mismatch, then the actual code bug — each ruled out with a concrete command
rather than a guess. The bug: two structurally identical `consul_keys` blocks side by side,
one parameterised by environment, one hardcoded to `/default`. Also closed out Workload
Identity: a Kubernetes ServiceAccount and a GCP IAM service account are two identities
linked by an annotation, not by name, and that was verified with `kubectl` rather than
trusting the apply log.

## Where Session 4 picks up

From Session 3's notes and the current assessment:

1. Decide on `cloudsql/infra` — a real Cloud SQL instance (real cost) versus continuing in
   mock-data mode.
2. `frontend/infra` hasn't been touched at all yet.
3. Two overdue transfer checks: a *fresh* `for_each`-guard scenario (the pattern was taught
   in Session 2 but never independently applied), and a deliberate audit for the same
   hardcoded-vs-parameterised Consul path bug in `frontend/infra` and `cloudsql/infra`
   rather than assuming Session 3's fix generalised.
4. Cost: check what's still running before starting. `./destroy-all.sh` when pausing.

## Conventions

- One file per session: `session-NN.md`, numbered not dated, since sessions 1 and 2 share a
  date.
- `learner-state.md` (alongside these notes, not published to the site) is the **living**
  assessment — competency matrix, readiness gates, recurring mistakes. It is overwritten
  each session rather than appended to.
- `archive/` holds the superseded snapshots of that living document, named for the session
  they follow. They exist so the *trajectory* is recoverable; don't edit them.
- New quiz questions from a session go into the matching
  [topic page](../quiz/index.md), tagged `<!-- source: session-NN -->`.
