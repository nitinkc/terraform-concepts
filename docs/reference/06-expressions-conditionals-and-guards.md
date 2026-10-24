# 6 — Expressions, Conditionals & Guard Propagation

**Code:** `acme-sampleapp-.../backend/infra/cloudsql.tf` · `infrastructure/infra/main.tf` · **Quiz:** [Variables, Expressions & Guards](../quiz/03-variables-expressions-and-guards.md)

---

## Architect's Points to Keep in Mind

### 1. Core HCL Expression Primitives
HCL is purely functional — there are no procedural `if` statements or mutable variables.

| Construct | Syntax | Key Rule / Use Case |
|---|---|---|
| **Bare reference vs. Interpolation** | `count = var.num` vs. `name = "${var.prefix}-app"` | Never wrap a standalone reference in `"${...}"` — it coerces numbers/booleans to strings. |
| **Ternary conditional** | `var.env == "prod" ? 100 : 20` | Both branches must resolve to compatible types. |
| **`coalesce(a, b, "default")`** | First non-null / non-empty value | Cleaner than nested ternaries for fallback chains. |
| **`try(expr, fallback)`** | Returns `fallback` if `expr` errors | Essential for indexing maps/JSON that may not contain a key (`try(local.map["dev"].ip, "")`). |
| **`one(list)`** | Returns `list[0]` if length is 1, `null` if empty | Idiomatic way to read an attribute from a `count = 0 / 1` resource (`one(resource.main[*].ip)`). |
| **Splat (`[*]`)** | `google_service_account.sa[*].email` | Works on **lists / `count` resources**. For `for_each` maps, use `values(map)[*].email` or a `for` expression. |

### 2. `for` Expressions (Data Transformation, Not Resource Loops)

- **`[for x in coll : ...]` (square brackets)** produces a **tuple/list**.
- **`{ for k, v in coll : k => v if cond }` (curly braces)** produces an **object/map**, optionally filtered by `if`.
- Filtering a map in `locals` before passing it to a module's `for_each` keeps conditionality out of reusable child modules.

### 3. The `count = 0` Empty-List Trap
HCL cannot conditionally declare a block; instead, `count = var.enabled ? 1 : 0` creates a **list of 0 or 1 instances**.

- When `count = 0`, `google_sql_database_instance.main` is an **empty list `[]`**, *not* an object with `null` fields.
- Referencing `google_sql_database_instance.main.name` fails (`Because count is set, its attributes must be accessed on specific instances`).
- Referencing `google_sql_database_instance.main[0].name` when `count = 0` fails (`Invalid index: list has 0 elements`).
- **Safe read patterns:**
  ```hcl
  value = one(google_sql_database_instance.main[*].name)
  # or
  value = length(google_sql_database_instance.main) > 0 ? google_sql_database_instance.main[0].name : null
  # or
  value = try(google_sql_database_instance.main[0].name, null)
  ```

### 4. Guard Propagation (Production Architecture Deep-Dive)

- **The Rule:** **A guard only protects the exact expression it wraps.** Every downstream consumer of a conditionally created or filtered resource must either:
    1. Iterate over the **exact same filtered keyset**, OR
    2. Carry its own defensive guard (`try()`, `one()`, `length() > 0`).
- **Real Incident Pattern (`infrastructure/infra`):**
    - `local.program_gcp_by_env` filtered `["dev", "qa", "prod"]` down to only environments whose upstream GKE cluster existed (`dev` and `qa`, skipping `prod`).
    - Downstream resources in `secrets.tf` and `outputs.tf` still iterated over the *unfiltered* `for_each = toset(local.environments)` and indexed `local.program_gcp_by_env[each.key]` — crashing on `"prod"` with `Invalid index`.
    - **Architectural Fix:** Define `local.available_environments = toset(keys(local.program_gcp_by_env))` once, and drive every downstream `for_each` from `local.available_environments`.

### 5. Design Judgment: When to Guard (`try()`) vs. When to Fail Fast

- **Do NOT blanket-wrap every external read in `try(..., "")`.**
- **Guard when the dependency is genuinely optional** and the application has a valid fallback (e.g., in `backend/infra/cloudsql.tf`, missing Cloud SQL Consul keys safely evaluate `cloudsql_enabled = false` so the backend runs in mock-data mode).
- **Fail fast when the dependency is a hard prerequisite** (e.g., in `backend/infra/main.tf`, missing `infrastructure` SSO secrets call `jsondecode()` directly without `try()`, failing immediately at `plan` time rather than deploying a broken pod).

---

## Code Reference

=== "Local Conditional & Guard"

    ```hcl
    variable "create_backup_file" {
      type    = bool
      default = false
    }

    resource "local_file" "backup" {
      count    = var.create_backup_file ? 1 : 0
      filename = "/tmp/backup.txt"
      content  = "Conditional backup payload"
    }

    # Safe output — handles count = 0 without index error
    output "backup_path" {
      value = coalesce(one(local_file.backup[*].filename), "not created")
    }
    ```

=== "GCP / Sandbox Guard Propagation (`infrastructure` & `backend`)"

    ```hcl
    # 1. Canonical filtered keyset propagation (infrastructure/infra/main.tf)
    locals {
      environments = ["dev", "qa", "prod"]

      # Filter to only environments where the upstream GKE cluster (p or np) exists in Consul
      program_gcp_by_env = {
        for env in local.environments :
        env => local.program_gcp_raw[env == "prod" ? "p" : "np"]
        if contains(keys(local.program_gcp_raw), env == "prod" ? "p" : "np")
      }

      # Derive filtered keyset ONCE and use it in every downstream `for_each`
      available_environments = toset(keys(local.program_gcp_by_env))
    }

    resource "google_secret_manager_secret" "sso" {
      for_each  = local.available_environments # Never `toset(local.environments)`!
      secret_id = "acme-sso-${each.key}"
      project   = local.program_gcp_by_env[each.key].project
      replication { auto {} }
    }

    # 2. Optional dependency guarded vs. Hard prerequisite fail-fast (backend/infra)
    locals {
      # Hard prerequisite (SSO): no `try()` — fail fast at plan time if unpublished
      app_infra = jsondecode(data.consul_keys.remote_outputs.var.infrastructure).outputs

      # Optional dependency (Cloud SQL): guarded with `try()` — degrades to mock mode
      cloudsql_raw     = try(data.consul_keys.remote_outputs.var.cloudsql, "")
      cloudsql_enabled = local.cloudsql_raw != "" && local.cloudsql_raw != null
      cloudsql_outputs = local.cloudsql_enabled ? jsondecode(local.cloudsql_raw).outputs : null
    }
    ```
