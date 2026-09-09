# 8 — Expressions and conditionals

**Assumes:** [Variables and locals](07-variables-and-locals.md).

HCL has no `if` statement, no `for` loop, and no way to assign twice. What it has is
expressions: everything is a value computed from other values. This page covers the
expression forms you need before [`count`/`for_each`](09-count-for-each-and-dynamic.md)
makes sense.

## Interpolation and references

```hcl
name = "${var.prefix}-app"        # interpolation, only needed inside a string
count = var.instance_count        # bare reference — no ${} required
```

Wrapping a whole value in `"${...}"` when it isn't part of a larger string is the most
common stylistic error; `terraform fmt` won't fix it, and it turns a number into a string.

## The conditional expression

```hcl
locals {
  is_prod   = var.environment == "prod"
  disk_size = local.is_prod ? 100 : 20
}
```

The ternary is the *only* conditional. Both branches must be the same type — Terraform will
try to convert, and `condition ? 1 : "none"` fails rather than doing something clever.

For "use this unless it's null/empty", two functions read better than nested ternaries:

| Expression | Returns |
|---|---|
| `coalesce(var.a, var.b, "fallback")` | first non-null argument |
| `try(local.m["k"], "default")` | the expression, or the default if it errors |
| `one(google_sql_database_instance.main)` | the single element, or `null` if the list is empty |

`one()` is worth remembering specifically because of the guard problem below.

## `for` expressions

A `for` expression transforms a collection into another collection. It is not a loop that
creates resources — that's `for_each`.

```hcl
locals {
  # list -> list
  upper_names = [for n in var.names : upper(n)]

  # map -> map, with a filter
  prod_only = { for k, v in var.envs : k => v if v.enabled }

  # collection -> map keyed by an attribute
  by_id = { for sa in var.service_accounts : sa.account_id => sa }
}
```

Square brackets produce a list (a *tuple*), braces produce a map (an *object*). The `if`
clause at the end is how filtering is done, and filtering in `locals` rather than inside a
module is the standard way to keep conditionality out of module internals.

The map-building form shows up constantly with `for_each` over modules:

```hcl
output "app_sa_emails" {
  value = { for k, m in module.app_sa : k => m.email }
}
```

## Splat

```hcl
google_service_account.gsa[*].email      # every instance's email, as a list
```

Shorthand for `[for s in google_service_account.gsa : s.email]`. Useful on
`count`-created resources; on `for_each`-created ones prefer the explicit `for` form, since
the result of a splat over a map is easy to misread.

## Conditional creation: `count = <bool> ? 1 : 0`

There is no way to conditionally *declare* a block. There is only a way to declare it with
zero instances.

```hcl
variable "enable_cloudsql" {
  type    = bool
  default = false
}

resource "google_sql_database_instance" "main" {
  count = var.enable_cloudsql ? 1 : 0
  # ...
}
```

**`count = 0` is an empty list, not an empty resource.** This is the part that trips
everyone up:

```hcl
value = google_sql_database_instance.main.name       # error: index required
value = one(google_sql_database_instance.main).name  # null-safe
```

The resource is not a single object with empty attributes — it is a *list of instances that
happens to have zero elements*. There is no `.name` to read because there is no instance to
read it from.

## Guard propagation

The consequence scales badly, and it is worth internalising while it's cheap. Every
**consumer** of a conditionally-created resource has to re-apply the guard. The condition
lives in one place; the defensive `length() > 0` / `one()` / `try()` checks spread to
everywhere that reads it.

```hcl
# the condition
count = var.enable_cloudsql ? 1 : 0

# every reader now needs one of these
length(google_sql_database_instance.main) > 0 ? google_sql_database_instance.main[0].ip : null
try(google_sql_database_instance.main[0].ip, null)
try(one(google_sql_database_instance.main).ip, null)
```

In the sandbox this is exactly the bug that cost a full debugging session: a module
`for_each`'d over a filtered map produces zero instances when everything is disabled, and
each downstream reference has to cope with the empty map independently
([Session 2](../sessions/session-02.md)).

Mitigations, in order of preference:

1. Filter in `locals` so the module never knows it was conditional.
2. Have the module always output a value — `null` or `""` — rather than making callers
   inspect instance counts.
3. Accept the guards, and put them all in one `locals` block instead of scattering them.

## Key takeaway

Everything is an expression, and the only conditional is the ternary. Conditional
infrastructure is therefore always expressed as *zero instances*, and the cost of that is
paid by every consumer downstream — so decide *where* the condition lives before you write
it.

---

Labs: [Conditionals](../basics/08-conditionals.md) ·
Quiz: [Variables, expressions & guards](../quiz/03-variables-expressions-and-guards.md) ·
Next: [count, for_each and dynamic](09-count-for-each-and-dynamic.md)
