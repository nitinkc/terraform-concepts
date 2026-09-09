# 6 — Dependencies and the graph

**Assumes:** [Resource identity and change behaviour](05-resource-identity-and-change.md).

Terraform doesn't execute your files top to bottom. It builds a **directed graph** of
references, then walks it — creating independent resources in parallel and dependent ones
in order.

## Referencing an attribute *is* declaring a dependency

```hcl
resource "local_file" "pet" {
  content = "Here is the Random Pet ${random_pet.my_pet.id}"
}

resource "random_pet" "my_pet" {
  length = 2
}
```

`random_pet.my_pet.id` is unknown until the pet is created, so Terraform *must* order the
two — and it worked that out from the string interpolation alone. There is no "enable
implicit dependencies" switch, because the reference already created the edge. The order
of blocks in the file, and the order of files in the directory, are both irrelevant.

## `depends_on` — for edges HCL can't see

```hcl
resource "google_storage_bucket" "b" {
  # ...
  depends_on = [google_project_service.storage_api]
}
```

`depends_on` earns its place only when the dependency is real but invisible to HCL:

- IAM permissions that must propagate before the resource using them is created
- an API that must be enabled before anything can call it
- a `null_resource` script that must run first

If you already interpolate an attribute of X into Y, adding `depends_on = [X]` is
redundant — generate both graphs and compare, they're identical. Redundant `depends_on`
isn't harmful, but it does mislead the next reader into thinking the edge wouldn't exist
otherwise.

## Destroy order is the reverse

The same graph drives teardown, walked backwards: dependents are destroyed before their
dependencies. This is why a `depends_on` you added to fix a create-ordering problem can
silently fix — or cause — a destroy-ordering problem too.

## Unknown values at plan time

An attribute that doesn't exist yet shows as `(known after apply)` in the plan. That's the
graph telling you it can't compute this until the upstream resource is created. It becomes
a real problem in two places:

- **`count`/`for_each` cannot depend on an unknown value.** The number of instances must be
  known at plan time, so `for_each` over something derived from a not-yet-created resource
  fails with "the for_each value depends on resource attributes that cannot be determined
  until apply". The fix is to key off a variable or local, not a resource attribute.
- **A `data` source that depends on a resource** is re-read after that resource is created,
  which is usually what you want and occasionally forces an extra apply.

## Seeing the graph

```bash
terraform graph | dot -Tsvg > graph.svg     # needs Graphviz
```

Worth doing once on a config you already understand, so the picture and your mental model
can be checked against each other. A pre-generated one is committed at
`01-basics/4-dependencies/implicit/graph.svg`.

## Key takeaway

The graph comes from references, not from files, block order, or filenames. Reach for
`depends_on` only when the ordering requirement exists in the real world but nowhere in
your HCL.

---

Labs: [References and dependencies](../basics/04-references-and-dependencies.md),
[Lab 3](../gcp/02-lab-notes.md#lab-3-implicit-dependency-iam-binding) ·
Next: [Variables and locals](07-variables-and-locals.md)
