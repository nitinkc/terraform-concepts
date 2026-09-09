# 9 — `count`, `for_each` and `dynamic`

**Assumes:** [Expressions and conditionals](08-expressions-and-conditionals.md).

Three mechanisms for repetition, and the first question to ask is *what* is being repeated:

| Mechanism | Repeats | Instance address |
|---|---|---|
| `count` | a whole resource or module | `type.name[0]` — positional |
| `for_each` | a whole resource or module | `type.name["key"]` — keyed |
| `dynamic` | a **nested block inside one** resource | none — there's still one resource |

`count` and `for_each` are meta-arguments handled by Terraform core, so they work on any
resource, data source or module. They are mutually exclusive on a single block.

## `count` — positional

```hcl
resource "local_file" "multi" {
  count    = 3
  filename = "/tmp/pet-${count.index}.txt"
  content  = "This is pet file number ${count.index}"
}
```

Three addressable instances from one block:

```
local_file.multi[0]
local_file.multi[1]
local_file.multi[2]
```

**The flaw is the index.** Remove an item from the *middle* of a list driving the count and
every subsequent index shifts. Terraform reads a shifted index as a different resource:
destroy and recreate, not rename. With a list of three service accounts, deleting the first
one churns all three.

## `for_each` — keyed

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

Addresses are keyed, not indexed:

```
local_file.named_pets["fido"]
local_file.named_pets["rex"]
local_file.named_pets["whiskers"]
```

Remove `"whiskers"` and re-plan: **only** `named_pets["whiskers"]` is destroyed. The other
two are untouched. That single experiment is the entire argument for `for_each`.

| | `count` | `for_each` |
|---|---|---|
| Accepts | a number | a `set(string)` or a `map(any)` |
| Iterator | `count.index` | `each.key`, `each.value` |
| Mid-collection removal | churns everything after it | affects only that key |
| Key must be known at plan time | yes | yes — and it must be a *string* |

## Which to use

Prefer `for_each` whenever items can be added to or removed from the middle of a
collection. Reserve `count` for two cases:

- N genuinely identical copies where position carries no meaning
- the conditional 0/1 pattern from [§8](08-expressions-and-conditionals.md)

## Two failure modes worth recognising

**Keys can't depend on unknown values.** `for_each` over something derived from a
not-yet-created resource fails with *"the for_each value depends on resource attributes
that cannot be determined until apply"*. Terraform has to know the instance set before it
can build the [graph](06-dependencies-and-the-graph.md). Key off variables or locals
instead.

**A list is not a set.** `for_each = var.names` where `names` is `list(string)` works
because Terraform converts, but the resulting keys are the *values*, not the positions —
and duplicates in the list become a hard error rather than two instances. Declare the type
you actually mean.

## `for_each` over modules

`for_each` on a `module` block behaves identically, and nests the key inside the module
address:

```hcl
module "app_sa" {
  source       = "./modules/service_account"
  for_each     = var.service_accounts       # map(object({...}))
  project_id   = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
}

output "app_sa_emails" {
  value = { for k, m in module.app_sa : k => m.email }
}
```

```
module.app_sa["dev"].google_service_account.this
module.app_sa["staging"].google_service_account.this
```

See [Modules](12-modules.md) and
[Lab 13](../gcp/02-lab-notes.md#lab-13-for_each-over-modules).

## `dynamic` — repeating a nested block

Some resources take repeatable *nested* blocks: lifecycle rules on a bucket, bindings in a
policy, ports on a firewall rule. `dynamic` generates them from a collection instead of
writing each by hand.

```hcl
locals {
  lifecycle_rules = [
    { age = 30,  storage_class = "NEARLINE" },
    { age = 90,  storage_class = "COLDLINE" },
    { age = 365, storage_class = "ARCHIVE" },
  ]
}

resource "google_storage_bucket" "demo" {
  name     = "${local.name_prefix}-lifecycle"
  location = "US"

  dynamic "lifecycle_rule" {
    for_each = local.lifecycle_rules
    content {
      condition { age = lifecycle_rule.value.age }
      action {
        type          = "SetStorageClass"
        storage_class = lifecycle_rule.value.storage_class
      }
    }
  }
}
```

Anatomy: the label after `dynamic` is the **nested block name being generated**, the
iterator is named after that label (`lifecycle_rule.key`, `lifecycle_rule.value`, override
with `iterator = x`), and everything to be repeated goes inside `content {}`.

Still **one** resource, one state address. Nothing in `terraform state list` changes when
you convert three hand-written blocks into a `dynamic` — which is a good way to verify the
refactor didn't change anything.

`dynamic` is also the most readable-code-destroying feature in HCL. Three hand-written
blocks are clearer than a `dynamic` over a three-element local. Use it when the count is
genuinely variable, not to avoid repetition you can see all of at once.

## Key takeaway

`count` is positional and therefore fragile; `for_each` is keyed and therefore stable.
`dynamic` is a different axis entirely — inside one resource, not across many. Confusing
the axes is the single most common source of "why did it recreate everything".

---

Labs: [count and for_each](../basics/07-count-and-for-each.md),
[Lab 4](../gcp/02-lab-notes.md#lab-4-count-indexed-multiple-resources),
[Lab 5](../gcp/02-lab-notes.md#lab-5-for_each-keyed-multiple-resources),
[Lab 12](../gcp/02-lab-notes.md#lab-12-dynamic-blocks) ·
Quiz: [Variables, expressions & guards](../quiz/03-variables-expressions-and-guards.md) ·
Next: [Outputs](10-outputs.md)
