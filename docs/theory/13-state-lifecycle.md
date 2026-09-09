# 13 — State lifecycle: drift, refresh, loss, import

**Assumes:** [Resources and state](04-resources-and-state.md).

Everything on this page is a consequence of state being a separate ledger from reality.

## Drift and the refresh phase

**Drift** — the real cloud resource no longer matches what's recorded in state/config, e.g.
someone edited it in the console.

**Refresh** — on every `plan`/`apply`, Terraform queries the live provider API for each
*managed* resource and compares three things: your HCL, the real world, and state.
**HCL always wins.** The plan proposes changes to bring the real world back in line with
code, never the reverse.

Two important limits:

- **Unmanaged resources are invisible.** A bucket created by hand and never imported
  produces no drift, no warning, nothing. Terraform only refreshes what's in state.
- **[`ignore_changes`](05-resource-identity-and-change.md) suppresses drift** on the listed
  attributes deliberately. If a manual edit isn't being reverted, that's the first thing to
  check.

## State loss

Delete `terraform.tfstate` while the real resources still exist and Terraform's memory is
blank. It does **not** rescan the cloud to rediscover ownership. It sees resources in your
code with no matching state entry, so it plans to **create** them — and the apply fails
when the API rejects the request because something already exists with that identifying
field.

This is recoverable, but only by hand, one resource at a time, with `import`. It is the
main argument for a [remote backend with versioning](14-backends-and-state-security.md).

## `import` — adopting an existing resource

```hcl
resource "google_storage_bucket" "manual" {
  name     = "acme-manual-bucket-my-project"
  location = "US"
}
```

```bash
terraform import google_storage_bucket.manual acme-manual-bucket-my-project
terraform plan
```

Three properties of `import` that surprise people:

1. **It only writes state.** It does not generate HCL for you — you write the resource
   block first, as an anchor.
2. **It does not validate your HCL against reality.** If the bucket was created in
   `us-central1` and your code says `US`, the next plan shows a diff you have to resolve.
   Import binds identity; matching attributes is still your job.
3. **The ID format is provider-specific** and often not the name — project-qualified paths,
   `projects/x/…` URIs, composite IDs. It's documented at the bottom of each resource's
   provider docs page.

Terraform 1.5+ also has a declarative `import` block, which works in a plan and is
reviewable, unlike the CLI command:

```hcl
import {
  to = google_storage_bucket.manual
  id = "acme-manual-bucket-my-project"
}
```

## State surgery

| Command | Effect | Real resource |
|---|---|---|
| `terraform state list` | list tracked addresses | untouched |
| `terraform state show <addr>` | show recorded attributes | untouched |
| `terraform state mv <old> <new>` | rename an address | untouched |
| `terraform state rm <addr>` | forget it — becomes unmanaged | **untouched** |
| `terraform import <addr> <id>` | adopt an existing resource | untouched |

None of these change infrastructure; all of them change what Terraform believes it owns.
`state rm` followed by an `apply` is how you accidentally create a duplicate, and
`state rm` followed by nothing is how you deliberately hand a resource over to another
config.

Take a copy of the state file before any surgery. With a
[remote backend](14-backends-and-state-security.md) that's automatic; locally it's `cp`.

## Workspaces — isolated state, same code

```bash
terraform workspace list          # * marks current
terraform workspace new dev
terraform workspace select dev
terraform workspace show
```

Each workspace is a **separate state file for the same configuration**. Switching
workspaces switches which state `plan`/`apply` reads and writes; resources in one are
invisible to another. The current name is available as `terraform.workspace`:

```hcl
resource "google_storage_bucket" "demo" {
  name = "${local.name_prefix}-${terraform.workspace}-demo"
}
```

**The production caveat:** workspaces isolate state but not provider configuration, so they
don't cleanly express "dev is in project A, prod is in project B" — and they make it easy
to apply to the wrong environment because the only difference is invisible CLI state. Most
production repos use separate directories or separate backend prefixes per environment
instead. Workspaces are worth knowing for the isolation concept and for short-lived
throwaway state, not as the default environment strategy.

## Key takeaway

Terraform's beliefs and reality diverge in exactly four ways: drift (reality changed),
invisibility (never in state), loss (state gone), and mis-addressing (state points at the
wrong thing). `refresh`, `import`, and `state mv`/`rm` are the four corresponding repairs.

---

Labs: [State surgery](../basics/12-state-surgery.md),
[Lab 6](../gcp/02-lab-notes.md#lab-6-state-surgery-mv-rm-import),
[Lab 10](../gcp/02-lab-notes.md#lab-10-workspaces-multi-environment-state-isolation),
[Lab 11](../gcp/02-lab-notes.md#lab-11-import-drift-detection) ·
Quiz: [Resources, state & drift](../quiz/02-resources-state-and-drift.md) ·
Next: [Backends and state security](14-backends-and-state-security.md)
