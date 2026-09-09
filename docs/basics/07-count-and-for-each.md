# 7 — count and for_each

**Folder:** none yet — paste this into a scratch root.

Both create multiple instances from one resource block. The difference is how instances are
addressed, and that difference decides what happens when the collection changes.

## count — positional

```hcl
resource "local_file" "multi" {
  count    = 3
  filename = "/tmp/pet-${count.index}.txt"
  content  = "This is pet file number ${count.index}"
}
```

```bash
terraform apply
ls /tmp/pet-*.txt
terraform state list
```

Three separate addressable instances from one block:

```
local_file.multi[0]
local_file.multi[1]
local_file.multi[2]
```

**The flaw:** change `count = 3` to `count = 1` and re-plan. Terraform proposes destroying
`multi[1]` and `multi[2]` — fine. But the real problem shows up when you remove an item
from the *middle* of a list driving the count. Every subsequent index shifts, and Terraform
reads a shifted index as a different resource: destroy and recreate, not rename.

## for_each — keyed

```hcl
variable "pet_names" {
  type    = set(string)
  default = ["fido", "whiskers", "rex"]
}

resource "local_file" "named_pets" {
  for_each = var.pet_names
  filename = "/tmp/pet-${each.value}.txt"
  content  = "Meet ${each.value}, a very good pet."
}
```

```bash
terraform apply
terraform state list
```

Addresses are keyed, not indexed:

```
local_file.named_pets["fido"]
local_file.named_pets["rex"]
local_file.named_pets["whiskers"]
```

## The destructive test

This single experiment is the entire argument for `for_each`. Remove `"whiskers"` from the
set and re-plan:

```bash
terraform plan
```

**Only** `named_pets["whiskers"]` is destroyed. `"fido"` and `"rex"` are untouched. Contrast
with the `count` version, where removing a middle element churns everything after it.

## Which to use

Prefer `for_each` whenever items can be added to or removed from the middle of a
collection. Reserve `count` for two cases:

- N genuinely identical copies where position carries no meaning
- the conditional 0/1 pattern — see [Conditionals](08-conditionals.md)

## The type matters

`count` needs an ordered `list(string)`; `for_each` needs a `set(string)` or a map. The
core GCP root keeps
[both declarations side by side](../gcp/01-core-root.md#things-worth-noticing) with the
`count` version commented out directly above the `for_each` version, specifically so you
can switch between them and diff `terraform state list`. The GCP versions of these two
sections are [Lab 4](../gcp/02-lab-notes.md#lab-4-count-indexed-multiple-resources) and
[Lab 5](../gcp/02-lab-notes.md#lab-5-for_each-keyed-multiple-resources).

`for_each` also applies to `module` blocks, not just resources —
[Lab 13](../gcp/02-lab-notes.md#lab-13-for_each-over-modules).

## Not the same as `dynamic`

`count` and `for_each` repeat *whole resources*. A `dynamic` block repeats a *nested block
inside one resource*. Different mechanism, easily confused — see
[Lab 12](../gcp/02-lab-notes.md#lab-12-dynamic-blocks), which is the only real `dynamic`
block in this repo.

---

Theory: [§9 count, for_each & dynamic](../theory/09-count-for-each-and-dynamic.md) ·
Quiz: [Variables, expressions & guards](../quiz/03-variables-expressions-and-guards.md) ·
Next: [Conditionals](08-conditionals.md)
