# 4 — Resources and state

**Assumes:** [terraform init and version constraints](03-init-and-version-constraints.md).

**Resource** — a block Terraform **owns and manages** the full lifecycle of: create,
update, delete. You describe the desired end state; Terraform works out the calls.

```hcl
resource "google_service_account" "gsa" {
  account_id   = "my-app"
  display_name = "My App"
}
```

Two labels: the **type** (`google_service_account`, defined by the provider) and the
**local name** (`gsa`, chosen by you). Together they form the resource's
[address](05-resource-identity-and-change.md).

## The state file

`terraform.tfstate` is Terraform's internal record mapping your HCL resource addresses to
real-world cloud resource IDs. This is the **only** mechanism by which Terraform knows
"this resource in my code = this specific thing in the cloud."

It is a JSON document. It is not a backup, not a source of truth about your intent, and
not something to edit by hand — but it is readable, and reading it when confused is a
legitimate debugging move.

## Why state exists — three reasons

1. **Identity / ownership mapping.** GCP has no concept of "this resource belongs to this
   Terraform config." State is that missing link.
2. **Performance.** Querying every resource's live API state on every command would be slow
   and would hit rate limits at scale.
3. **Metadata.** Dependency information and some computed values aren't always fully
   re-derivable from a live API query alone.

Reason 1 is the load-bearing one. Reasons 2 and 3 are optimisations; reason 1 is why a
declarative tool cannot work without a ledger.

## What follows from state existing

Nearly every operational surprise in Terraform is a consequence of this design:

| Situation | Consequence | Covered in |
|---|---|---|
| A resource is created outside Terraform | invisible — plan shows nothing | [State lifecycle](13-state-lifecycle.md) |
| The state file is deleted | Terraform plans to create things that already exist | [State lifecycle](13-state-lifecycle.md) |
| You rename a resource in code | destroy + create, not rename | [Resource identity](05-resource-identity-and-change.md) |
| A secret passes through a resource | it is written to state in plaintext | [Backends and state security](14-backends-and-state-security.md) |
| Two people apply at once | state can be corrupted without locking | [Backends and state security](14-backends-and-state-security.md) |

## Inspecting it

```bash
terraform state list                              # every address Terraform thinks it owns
terraform state show google_service_account.gsa    # full recorded attributes of one
```

`state list` after an apply is the single most useful habit in this section — it tells you
what Terraform believes, which is not always what you meant.

## Key takeaway

State is the *only* thing connecting your config to reality. Lose it and Terraform doesn't
go looking for orphans; it just tries to create again. Adoption of an existing resource is
always explicit.

---

Labs: [Resources and state](../basics/01-resources-and-state.md),
[Lab 1](../gcp/02-lab-notes.md#lab-1-local-state) ·
Quiz: [Resources, state & drift](../quiz/02-resources-state-and-drift.md) ·
Next: [Resource identity and change behaviour](05-resource-identity-and-change.md)
