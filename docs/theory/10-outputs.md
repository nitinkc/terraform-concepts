# 10 — Outputs

**Assumes:** [`count`, `for_each` and `dynamic`](09-count-for-each-and-dynamic.md).

An `output` block exposes a value from your config — for human inspection
(`terraform output`), for a shell script, for a
[module](12-modules.md) caller, or for another config reading your state
([§15](15-cross-config-composition.md)). Outputs are a config's public API; everything
else in it is private.

## Primitive output

```hcl
output "service_account_email" {
  description = "The email address of the created GCP service account."
  value       = google_service_account.gsa.email
}
```

```bash
terraform output service_account_email        # quoted, JSON-ish
terraform output -raw service_account_email   # bare string, safe for shell
```

`-raw` is what makes outputs usable from scripts without a JSON parser.

## Structured output

```hcl
output "service_account" {
  value = {
    id    = google_service_account.gsa.account_id
    email = google_service_account.gsa.email
  }
}
```

`-raw` does **not** work on this — it only works on primitives. Use:

```bash
terraform output -json service_account | jq -r '.email'
```

A structured output is the right choice when the consumer needs several related values;
one map is a stabler interface than five separate outputs.

## Outputs from multiple instances

```hcl
output "pet_filenames" {
  value = local_file.named_pets[*].filename                 # count-created
}

output "app_sa_emails" {
  value = { for k, m in module.app_sa : k => m.email }      # for_each over modules
}
```

For a conditionally-created resource, output `null` rather than making the caller inspect
instance counts — see [guard propagation](08-expressions-and-conditionals.md).

## Sensitive outputs

```hcl
output "service_account_private_key" {
  value     = google_service_account_key.mykey.private_key
  sensitive = true
}
```

`sensitive = true` **only masks CLI/terminal display** — `plan`/`apply` print
`<sensitive>` instead of the value. It does **not** encrypt anything, and the value is
still in state in plaintext ([§14](14-backends-and-state-security.md)). You can still read
it deliberately with `terraform output -raw <name>`, which is the intended escape hatch.

Terraform also refuses to let a sensitive value flow into a non-sensitive output — you get
an error telling you to mark the output sensitive too. That's contagion working as
designed, not a bug.

## The mistake you will actually make

```
Error: Reference to undeclared resource
```

Referencing the wrong *local name* inside an output — `google_service_account.app` when the
block is named `google_service_account.gsa`. The name inside `value` must match the
resource's declared local name exactly. It's a one-line fix and it costs everyone ten
minutes at least once.

## Key takeaway

Outputs are the interface. Anything a module caller, a shell script, or another repo needs
must be an output; anything that isn't an output is an implementation detail you're free to
refactor.

---

Labs: [Outputs](../basics/05-outputs.md),
[Lab 7](../gcp/02-lab-notes.md#lab-7-data-sources) ·
Next: [Data sources](11-data-sources.md)
