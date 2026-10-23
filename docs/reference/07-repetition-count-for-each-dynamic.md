# 7 — Repetition: `count`, `for_each` & `dynamic`

**Code:** `02-gcp-terraform/z-core-gcp-resources/resources.tf` · `02-gcp-terraform/3-acme-lab-step-by-step/main.tf` · **Quiz:** [Variables, Expressions & Guards](../quiz/03-variables-expressions-and-guards.md)

---

## Architect's Points to Keep in Mind

### 1. Choosing the Right Repetition Mechanism
First identify **what** is being repeated: whole resources/modules vs. nested blocks inside a single resource.

| Meta-Argument | Repeats | Input Type | Iterator | State Address | Mid-Collection Removal Behaviour |
|---|---|---|---|---|---|
| **`count`** | Whole `resource`, `data`, or `module` | `number` | `count.index` | `type.name[0]` *(positional)* | **Destructive shift:** every subsequent index shifts left, destroying & recreating survivors |
| **`for_each`** | Whole `resource`, `data`, or `module` | `set(string)` or `map(any)` | `each.key`, `each.value` | `type.name["dev"]` *(keyed)* | **Isolated:** destroys **only** the removed key; all other instances untouched |
| **`dynamic`** | **Nested block** inside 1 resource | `set` / `list` / `map` | `<label>.key`, `<label>.value` | `type.name` *(single resource)* | Updates the single parent resource in place |

- **Default to `for_each`** for almost all collections of cloud resources or modules.
- **Reserve `count` strictly for:**
  1. Conditional creation (`count = var.enabled ? 1 : 0`).
  2. $N$ identical, stateless copies where individual identity never matters.

### 2. Two `for_each` Failure Modes to Memorize
1. **Plan-Time Unknown Keys:** Keys in `for_each` must be known during `plan` (cannot be derived from computed attributes like `google_compute_instance.vm.id`). Use static map keys from `var.*` or `local.*`, and put the computed resource attributes in the map *values* instead.
2. **`list(string)` vs. `set(string)`:** `for_each` rejects a raw `list(string)` because lists allow duplicate elements and numeric ordering. Declare the variable as `type = set(string)`, or convert explicitly with `toset(var.list)` (which deduplicates and keys by string value).
   - *Migrating `count` to `for_each`:* Changing a resource from `count` (`env_sa[0]`) to `for_each` (`env_sa["dev"]`) changes its state address and will destroy + recreate every instance unless you migrate state with `moved {}` blocks or `terraform state mv`.

### 3. `for_each` Over Modules
- Applying `for_each` to a `module` block creates keyed module instances:
  `module.app_sa["dev"].google_service_account.this`.
- If the `for_each` map is empty (`{}`), Terraform cleanly creates **zero instances** with no error (used by `module "gke"` in `sample-program/infra/main.tf` when both `enable_gke_p` and `enable_gke_np` are `false`).
- Collect outputs across keyed module instances using a `for` comprehension:
  `{ for k, m in module.app_sa : k => m.email }`.

### 4. `dynamic` Blocks: Anatomy & Readability Trade-Off
- **Anatomy:**
  - Outer label (`dynamic "lifecycle_rule"`) must match the exact nested block name expected by the provider schema.
  - `for_each` supplies the collection.
  - `content { ... }` defines the generated nested block body, referencing `lifecycle_rule.value.<field>` (or a custom iterator name set via `iterator = rule`).
- **State impact:** Converting 3 static `lifecycle_rule {}` blocks into a `dynamic "lifecycle_rule"` block produces a **no-op plan** (`0 to change`) and does not alter `terraform state list`, because there is still only one `google_storage_bucket` resource.
- **Architect's Rule:** `dynamic` hurts readability when overused. Use it when nested blocks are parameterized via module variables or vary by environment (e.g., firewall `allow` rules, RBAC `rule` blocks, storage `lifecycle_rule` transitions).

---

## Code Reference

=== "Local (`count` vs. `for_each` Destructive Test)"

    ```hcl
    # Fragile positional addressing: removing index 0 shifts [1] -> [0] and [2] -> [1]
    resource "local_file" "multi" {
      count    = 3
      filename = "/tmp/pet-${count.index}.txt"
      content  = "Pet index ${count.index}"
    }

    # Stable keyed addressing: removing "whiskers" only destroys local_file.named_pets["whiskers"]
    variable "pet_names" {
      type    = set(string)
      default = ["fido", "whiskers", "rex"]
    }

    resource "local_file" "named_pets" {
      for_each = var.pet_names
      filename = "/tmp/pet-${each.value}.txt"
      content  = "Meet ${each.value}"
    }
    ```

=== "GCP Resources, Modules & `dynamic` (`02-gcp-terraform/`)"

    ```hcl
    # 1. Resource `for_each` (replaced fragile `count = length(var.environments)`)
    variable "environments" {
      type    = set(string)
      default = ["dev", "staging"]
    }

    resource "google_service_account" "env_sa" {
      for_each     = var.environments
      account_id   = "${local.name_prefix}-${each.value}"
      display_name = "SA for ${each.value} env"
    }
    # State addresses: google_service_account.env_sa["dev"], google_service_account.env_sa["staging"]

    # 2. `for_each` over a Child Module with structured map(object)
    variable "service_accounts" {
      type = map(object({
        account_id   = string
        display_name = string
      }))
      default = {
        dev     = { account_id = "acme-dev-app",     display_name = "Dev App SA" }
        staging = { account_id = "acme-staging-app", display_name = "Staging App SA" }
      }
    }

    module "app_sa" {
      source       = "./modules/service_account"
      for_each     = var.service_accounts
      project_id   = var.project_id
      account_id   = each.value.account_id
      display_name = each.value.display_name
    }
    # State addresses: module.app_sa["dev"].google_service_account.this

    output "app_sa_emails" {
      value = { for k, m in module.app_sa : k => m.email }
    }

    # 3. `dynamic` block — generates 3 nested `lifecycle_rule` blocks inside 1 bucket
    locals {
      lifecycle_rules = [
        { age = 30,  storage_class = "NEARLINE" },
        { age = 90,  storage_class = "COLDLINE" },
        { age = 365, storage_class = "ARCHIVE" },
      ]
    }

    resource "google_storage_bucket" "lifecycle_demo" {
      name                        = "${local.name_prefix}-lifecycle-${var.project_id}"
      location                    = "US"
      uniform_bucket_level_access = true

      dynamic "lifecycle_rule" {
        for_each = local.lifecycle_rules
        content {
          condition {
            age = lifecycle_rule.value.age
          }
          action {
            type          = "SetStorageClass"
            storage_class = lifecycle_rule.value.storage_class
          }
        }
      }
    }
    ```
