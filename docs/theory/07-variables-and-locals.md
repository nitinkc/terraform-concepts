# 7 — Variables and locals

**Assumes:** [Dependencies and the graph](06-dependencies-and-the-graph.md).

Two different jobs, often confused because both hold values.

| | `variable` | `locals` |
|---|---|---|
| Analogy | a function argument | a local variable inside the function |
| Set from outside? | yes — CLI, `.tfvars`, env var, `default` | never |
| Referenced as | `var.name` | `local.name` |
| Purpose | what changes per run/user/environment | what's derived once and reused |

**Which to use:** something that legitimately changes per run, user or environment (project
ID, target environment name) → `variable`. Something computed from other inputs and reused
throughout the config (a name prefix, a labels map, a prod-vs-nonprod flag) → `local`.

Naming trap: the block is `locals` (plural), the reference is `local.` (singular).

## Declaring a variable

```hcl
variable "project_id" {
  description = "The GCP project to create resources in"
  type        = string
  default     = "my-devops-journey-502420"
}
```

`description` is not decoration — it appears in `terraform plan` prompts and in generated
module documentation, and it's the only place a caller of a
[module](12-modules.md) learns what the input means.

## Type constraints

| Type | Example value | Notes |
|---|---|---|
| `string`, `number`, `bool` | `"us-central1"`, `3`, `true` | primitives |
| `list(string)` | `["a", "b"]` | ordered, duplicates allowed — what `count` wants |
| `set(string)` | `["a", "b"]` | unordered, unique — what `for_each` wants |
| `map(string)` | `{ env = "dev" }` | keyed |
| `object({...})` | `{ id = string, size = number }` | named fields, `optional()` for defaults |
| `any` | anything | opts out of checking; use sparingly |

The `list` vs `set` distinction is not pedantry — it decides whether
[`count` or `for_each`](09-count-for-each-and-dynamic.md) is available to you.

## Variable precedence

Highest priority first. Anything higher overrides anything lower for the same variable.

1. **CLI flags** — `-var="project_id=..."` or `-var-file="..."`
2. **`*.auto.tfvars`** — loaded automatically, in alphabetical order; among several, the
   alphabetically **last** wins for any overlapping variable
3. **`terraform.tfvars`** (or `.tfvars.json`) — the standard project variable file
4. **Environment variables** — `TF_VAR_<name>`, e.g. `TF_VAR_project_id`
5. **`default`** in the `variable` block — used only if nothing above supplies a value

Three points that are commonly guessed wrong:

- File-based inputs (`terraform.tfvars`) beat `TF_VAR_*` environment variables — files are
  treated as more explicit and more project-specific.
- `*.auto.tfvars` beats plain `terraform.tfvars`.
- Among multiple `*.auto.tfvars` files, alphabetically last wins.

A variable with no default and no supplied value is not an error at parse time — Terraform
interactively prompts for it, which is why a CI run can appear to hang instead of failing.

## `validation` — reject bad input early

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, prod."
  }
}
```

The condition is evaluated at plan time, before any API call. A typo becomes a clear
message instead of a half-created environment named `prodd`. The condition may only
reference the variable being validated — that restriction is what lets Terraform check it
so early.

## `sensitive` inputs

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

`sensitive = true` masks the value in CLI output, and taints anything derived from it so
that plans don't leak it indirectly. It does **not** encrypt anything, and the plaintext
still lands in the [state file](14-backends-and-state-security.md). It's protection against
shoulder-surfing and CI logs, not a security boundary.

## Volatile locals cause perpetual diffs

```hcl
locals {
  suffix = formatdate("YYYYMMDD", timestamp())
}
```

`timestamp()` re-evaluates on every plan, so any resource referencing a value derived from
it is *always* different and can never converge. When you genuinely need one, the standard
fix is [`ignore_changes`](05-resource-identity-and-change.md) on the affected attribute.

## Key takeaway

`variable` is the config's input schema; `locals` is its internal wiring. Most
"why is my value not what I set" incidents are precedence, and the answer is almost always
that a `.tfvars` file is quietly winning.

---

Labs: [Variables](../basics/02-variables.md), [Locals](../basics/03-locals.md),
[Validation and sensitive values](../basics/10-validation-and-sensitive-values.md),
[Lab 8](../gcp/02-lab-notes.md#lab-8-locals-computedderived-values),
[Lab 15](../gcp/02-lab-notes.md#lab-15-terraformtfvars-variable-precedence) ·
Quiz: [Variables, expressions & guards](../quiz/03-variables-expressions-and-guards.md) ·
Next: [Expressions and conditionals](08-expressions-and-conditionals.md)
