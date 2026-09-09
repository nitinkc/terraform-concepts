# 5 — Resource identity and change behaviour

**Assumes:** [Resources and state](04-resources-and-state.md).

**Resource address** = `resource_type.local_name`, e.g. `google_service_account.gsa`.
This address — not any attribute inside the block — is what Terraform uses as identity in
state. Instances created by `count`/`for_each` extend it with an index or key
(`google_service_account.gsa["dev"]`), and modules prefix it (`module.backend_sa.…`).

## Renaming in code is destroy + create

Terraform sees the old address missing from config (→ destroy) and a new address with no
state entry (→ create). It does **not** infer "this is the same thing, just renamed."

Two fixes, either is fine:

```bash
terraform state mv google_service_account.old google_service_account.new
```

```hcl
moved {
  from = google_service_account.old
  to   = google_service_account.new
}
```

The `moved` block (Terraform 1.1+) is the better choice in a shared repo: it's committed,
reviewable, and applies itself on everyone's next run, whereas `state mv` is a local
imperative act that each person has to remember to repeat.

## Two kinds of change

| Change type | Example | Behaviour |
|---|---|---|
| In-place update | `display_name` on a service account | provider PATCHes the field; resource ID unchanged |
| Force replacement ("Force New") | `account_id` on a service account | provider can't mutate this field via the API — Terraform destroys, then recreates |

Whether an attribute is in-place-updatable or force-new is defined by the **provider**, not
by Terraform core — it reflects real API constraints of the underlying service. Read the
plan output: Terraform always tells you which attribute forced the replacement, and
`# forces replacement` next to a line is the thing to look for before typing `yes`.

You can also force a replacement deliberately, without changing any attribute:

```bash
terraform apply -replace=random_pet.my_pet
```

## `lifecycle` — overriding the default behaviour

The `lifecycle` block is a meta-argument: it's interpreted by Terraform core, not by the
provider, and it's available on every resource.

| Option | Effect |
|---|---|
| `create_before_destroy` | stand the replacement up before tearing the old one down |
| `prevent_destroy` | hard-fail any plan that would delete this resource |
| `ignore_changes` | stop drift on the listed attributes from producing an update |
| `replace_triggered_by` | force replacement when another resource changes |

```hcl
resource "google_sql_database_instance" "main" {
  # ...
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [settings[0].disk_size]
  }
}
```

Four things worth knowing before using them:

- **`prevent_destroy` blocks replacement too**, not just an explicit `destroy` — including
  a replacement triggered by a force-new attribute change. That's usually what you want on
  a database, and occasionally an infuriating surprise.
- **`ignore_changes` takes attribute references, not strings**, and naming an attribute the
  resource doesn't have is an error. The
  [lifecycle lab](../basics/09-lifecycle.md) ships that error on purpose.
- **`ignore_changes` is correct when something outside Terraform legitimately owns one
  field** — an autoscaler adjusting a node count, a controller stamping an annotation.
  Without it, the two systems fight on every apply. It is not a way to silence a diff you
  don't understand.
- **`create_before_destroy` can't always work.** If the resource has a name uniqueness
  constraint, the new one can't exist alongside the old under the same name.

## Key takeaway

Identity is the address, not the name field. Change behaviour is the provider's decision,
not yours. `lifecycle` lets you override *when* Terraform acts, never *whether* the API
permits the change.

---

Labs: [Lifecycle](../basics/09-lifecycle.md),
[Lab 16](../gcp/02-lab-notes.md#lab-16-lifecycle-meta-arguments) ·
Quiz: [Resources, state & drift](../quiz/02-resources-state-and-drift.md) ·
Next: [Dependencies and the graph](06-dependencies-and-the-graph.md)
