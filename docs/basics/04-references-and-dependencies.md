# 4 — References and dependencies

**Folders:**
[`01-basics/3-resource-attribute-reference/`](https://github.com/nitinkc/terraform-concepts/tree/main/01-basics/3-resource-attribute-reference),
[`01-basics/4-dependencies/`](https://github.com/nitinkc/terraform-concepts/tree/main/01-basics/4-dependencies)

Terraform works out execution order from a **graph**, and almost always builds that graph
for you. These three directories exist to make one point: an implicit dependency isn't a
feature you turn on, it's what an attribute reference already *is*.

## Attribute references

One resource reads another's attributes. `random_pet.my_pet.id` is interpolated into
`local_file.pet`'s content:

```hcl
resource "local_file" "pet" {
  filename = var.fileName
  content  = "Here is the Random Pet ${random_pet.my_pet.id}"
}

resource "random_pet" "my_pet" {
  prefix    = var.prefix
  separator = var.separator
  length    = var.name_length
}
```

```bash
cd 3-resource-attribute-reference
terraform init && terraform apply
cat /tmp/hello_resourceAttribute.txt   # contains the generated pet name
```

The pet's `id` isn't known until the pet is created, so Terraform *must* order the two. It
worked that out from the string interpolation alone.

**Try this:** run `terraform apply` twice. The pet name doesn't change — `random_pet` is a
resource, so once it's in state Terraform keeps the value rather than regenerating it. Now
force it:

```bash
terraform apply -replace=random_pet.my_pet
```

Both resources change, because the file depends on the pet.

## Implicit dependencies

[`4-dependencies/implicit/`](https://github.com/nitinkc/terraform-concepts/tree/main/01-basics/4-dependencies/implicit)
writes `/tmp/hello_implicit_dependencies.txt`. Its `main.tf` is **byte-identical** to
`3-resource-attribute-reference/main.tf`:

```bash
diff 4-dependencies/implicit/main.tf 3-resource-attribute-reference/main.tf   # no output
```

That is not duplication to clean up — it is the lesson. The only differences between the
two directories are the variable defaults. There is no "enable implicit dependencies"
switch, because the reference in the previous section already created the edge.

## Explicit dependencies

[`4-dependencies/explicit/`](https://github.com/nitinkc/terraform-concepts/tree/main/01-basics/4-dependencies/explicit)
writes `/tmp/hello_explicit_dependencies.txt` and adds `depends_on` plus an `output`:

```hcl
resource "local_file" "pet" {
  filename = var.fileName
  content  = "Here is the Random Pet ${random_pet.my_pet.id}"

  depends_on = [
    random_pet.my_pet
  ]
}
```

```bash
cd 4-dependencies/explicit
terraform init && terraform apply
terraform output pet_output
```

**The `depends_on` here is redundant.** The content interpolation already creates the edge.
Generate both graphs and compare — they match.

`depends_on` earns its place only when the dependency is real but invisible to HCL:

- IAM permissions that must propagate before the resource using them is created
- a `null_resource` script that must run first
- an API that must be enabled before anything can call it

There's a real example of the IAM case in
[`backend/infra/main.tf`](https://github.com/nitinkc/terraform-concepts/blob/main/acme-sampleapp-multirepo-sandbox-elaborate/backend/infra/main.tf)
in the sandbox, and the GCP version of the implicit case is
[Lab 3](../gcp/02-lab-notes.md#lab-3-implicit-dependency-iam-binding).

## Seeing the graph

Needs Graphviz's `dot`:

```bash
terraform graph | dot -Tsvg > graph.svg
```

A pre-generated
[`graph.svg`](https://github.com/nitinkc/terraform-concepts/blob/main/01-basics/4-dependencies/implicit/graph.svg)
is checked in under `4-dependencies/implicit/`. It shows the single edge from
`local_file.pet` to `random_pet.my_pet` that Terraform derived purely from the string
interpolation — nothing was declared.

Run it on `explicit/` too and compare. Same graph.

## Key takeaway

Referencing an attribute *is* declaring a dependency. It also drives destroy order, which
is the reverse of create order. Reach for `depends_on` only when the ordering requirement
exists in the real world but nowhere in your HCL.

---

Theory: [§6 Dependencies and the graph](../theory/06-dependencies-and-the-graph.md) ·
Next: [Outputs](05-outputs.md)
