# 3 — Locals

**Folder:** none yet — paste this into a scratch root.

`locals` compute a value once and let you reuse it. Unlike a `variable`, a local is never
set from outside: no `.tfvars`, no CLI flag, no environment variable. It is derived from
other values inside the config.

## The code

```hcl
locals {
  timestamp_suffix = formatdate("YYYYMMDD", timestamp())
  base_dir         = "/tmp/tf-practice"
  full_greeting    = "Hello from ${var.prefix}! Generated on ${local.timestamp_suffix}."
}

resource "local_file" "computed" {
  filename = "${local.base_dir}/greeting-${local.timestamp_suffix}.txt"
  content  = local.full_greeting
}
```

## Run it

```bash
mkdir -p /tmp/tf-practice
terraform plan
terraform apply
cat /tmp/tf-practice/greeting-*.txt
```

## Volatile functions cause perpetual diffs

Re-run `terraform plan` immediately after apply, with no changes to anything:

```bash
terraform apply
terraform plan     # still shows a diff
```

`timestamp()` re-evaluates on every plan, so any resource referencing a value derived from
it is *always* different. The resource can never converge.

This is why volatile functions are used carefully in real configs. When you genuinely need
one — a build timestamp, a nonce — the usual fix is to stop Terraform caring about the
resulting drift:

```hcl
lifecycle {
  ignore_changes = [content]
}
```

See [Lifecycle](09-lifecycle.md) for what that does and when it's appropriate.

## `local` vs `locals`

A small naming trap: the block is `locals` (plural), the reference is `local.` (singular).
`local.base_dir`, never `locals.base_dir`.

## Key takeaway

Refactoring a resource to reference a `local` instead of an inline expression should
produce a **no-op plan** if the computed value is identical. That's a good way to confirm a
refactor didn't accidentally change real infrastructure — the GCP version of this is
[Lab 8](../gcp/02-lab-notes.md#lab-8-locals-computedderived-values), and the production-shaped
example is [`locals.tf`](../gcp/01-core-root.md) in the core GCP root.

---

Theory: [§7 Variables & locals](../theory/07-variables-and-locals.md) ·
Next: [References and dependencies](04-references-and-dependencies.md)
