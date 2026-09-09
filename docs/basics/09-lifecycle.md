# 9 — Lifecycle

**Folder:** [`01-basics/5-lifecycle/`](https://github.com/nitinkc/terraform-concepts/tree/main/01-basics/5-lifecycle)

The `lifecycle` block overrides Terraform's default create/update/destroy behaviour. Four
options, three of them commented out in `main.tf`:

| Option | Effect |
|---|---|
| `create_before_destroy` | Stand the replacement up before tearing the old one down |
| `prevent_destroy` | Hard-fail any plan that would delete this resource |
| `ignore_changes` | Stop drift on the listed attributes from triggering an update |
| `replace_triggered_by` | Force replacement when another resource changes |

## This folder does not apply cleanly — on purpose

```hcl
resource "local_file" "pet" {
  filename        = "/tmp/hello.txt"
  content         = "Hello! Let the learning commence...."
  file_permission = "0700"

  lifecycle {
    # create_before_destroy = true
    # prevent_destroy = true
    # ignore_changes = all
    ignore_changes = [
      tags
    ]
  }
}
```

`ignore_changes = [tags]` names an attribute that `local_file` does not have. Observe the
error before fixing it:

```bash
terraform init && terraform apply
```

## Fix it three ways

**1 — point `ignore_changes` at a real attribute:**

```hcl
lifecycle {
  ignore_changes = [content]
}
```

```bash
terraform apply
echo "manually changed content" > /tmp/hello.txt
terraform plan   # NO changes, despite the file content now differing
```

Terraform sees the drift and deliberately ignores it. Compare with
[Resources and state](01-resources-and-state.md), where the same drift produced a plan to
correct it.

**2 — guard against deletion:**

```hcl
lifecycle {
  prevent_destroy = true
}
```

```bash
terraform apply
terraform destroy   # fails with an explicit prevent_destroy error
```

Note this blocks *any* plan that would delete the resource, including a replacement
triggered by changing a force-new attribute — not just an explicit `destroy`.

**3 — `create_before_destroy`:** replace the old instance only once the new one exists.
Matters for resources with a name uniqueness constraint or something depending on them
staying reachable; for a local file it's academic.

## When `ignore_changes` is the right answer

When something outside Terraform legitimately owns one field. A separate automation that
stamps labels, a controller that writes an annotation, an autoscaler that adjusts a node
count. Without `ignore_changes` those two systems fight on every apply, each reverting the
other.

It's also the standard fix for the volatile-function problem from
[Locals](03-locals.md#volatile-functions-cause-perpetual-diffs).

The GCP version of both guards is
[Lab 16](../gcp/02-lab-notes.md#lab-16-lifecycle-meta-arguments), and the sandbox uses
`prevent_destroy` on its Cloud SQL instance for real.

---

Theory: [§5 Resource identity](../theory/05-resource-identity-and-change.md) ·
Next: [Validation and sensitive values](10-validation-and-sensitive-values.md)
