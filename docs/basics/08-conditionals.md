# 8 — Conditionals

**Folder:** none yet — paste this into a scratch root.

Terraform has no `if` statement. Conditional creation is done with `count = <bool> ? 1 : 0`,
which turns a resource into either a one-element or a zero-element list of instances.

## The code

```hcl
variable "create_backup_file" {
  type    = bool
  default = false
}

resource "local_file" "backup" {
  count    = var.create_backup_file ? 1 : 0
  filename = "/tmp/backup.txt"
  content  = "This only exists if the flag is true."
}
```

```bash
terraform plan                                    # default false — 0 resources, nothing created
terraform plan -var="create_backup_file=true"     # now shows 1 to add
```

## `count = 0` is an empty list, not an empty resource

This is the part that trips people up. Reference it the obvious way, on purpose:

```hcl
output "backup_path" {
  value = local_file.backup.filename   # WRONG when count is used — no index given
}
```

```bash
terraform plan
```

Expect an error telling you an index is required. The resource is not a single object with
empty attributes — it is a **list of instances that happens to have zero elements**. There
is no `.filename` to read because there is no instance to read it from.

The fix has to handle the empty case explicitly:

```hcl
output "backup_path" {
  value = length(local_file.backup) > 0 ? local_file.backup[0].filename : "not created"
}
```

## Guard propagation

The consequence scales badly, and it's worth internalising here where it's cheap. Every
*consumer* of a conditionally-created resource has to re-apply the guard. The condition
lives in one place; the defensive `length() > 0` checks spread to everywhere that reads it.

In the sandbox this is exactly the bug that cost a full debugging session: a module
`for_each`'d over a filtered map produces zero instances when everything is disabled, and
each downstream reference has to cope with the empty map independently. See
[Session 2](../sessions/session-02.md) and the
[guard propagation](../theory/concept-index.md) row in the concept index.

The mitigation is to filter in `locals` rather than inside the module, so the module never
knows it was conditional — but the guard still has to be re-applied by each consumer of the
filtered collection.

## Real-world shape

The pattern in production code usually reads:

```hcl
resource "google_sql_database_instance" "main" {
  count = var.enable_cloudsql ? 1 : 0
  # ...
}
```

…with every reference to it written as `google_sql_database_instance.main[0]` guarded by
the same flag, or `one(google_sql_database_instance.main)` which returns `null` instead of
erroring on an empty list.

---

Theory: [§8 Expressions & conditionals](../theory/08-expressions-and-conditionals.md) ·
Quiz: [Variables, expressions & guards](../quiz/03-variables-expressions-and-guards.md) ·
Next: [Lifecycle](09-lifecycle.md)
