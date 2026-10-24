# 5 — Variables, Precedence, Locals & Sensitive Data

**Code:** `01-basics/2-variable-locals/` · `02-gcp-terraform/z-core-gcp-resources/variables.tf`, `locals.tf` · **Quiz:** [Variables, Expressions & Guards](../quiz/03-variables-expressions-and-guards.md)

---

## Architect's Points to Keep in Mind

### 1. `variable` vs. `locals`
| Construct | Analogy | Set Externally? | Block Syntax | Reference Syntax | Purpose |
|---|---|---|---|---|---|
| `variable` | Function parameter | **Yes** (CLI, `.tfvars`, `TF_VAR_*`) | `variable "x" {}` | `var.x` | External inputs varying per environment/caller |
| `locals` | Internal constant / computed wire | **Never** | `locals { x = ... }` *(plural)* | `local.x` *(singular)* | Derived values, DRY prefixes, common labels, filtered maps |

- **No-Op Refactor Rule:** Extracting repeated inline expressions into `locals` must produce a **`0 to add, 0 to change, 0 to destroy`** plan if the evaluated strings are identical. Always run `terraform plan` after a `locals` refactor to verify.
- **Unused `variable` blocks are a code smell:** Terraform does not warn when a declared variable in `variables.tf` is never referenced — it usually indicates a hardcoded value that forgot to wire `var.<name>`.

### 2. Variable Precedence Order (High-Frequency Interview Question)
From **lowest** priority (overridden by everything below it) to **highest** priority (wins unconditionally):

1. `default` inside the `variable` block *(lowest — fallback only)*
2. `TF_VAR_<name>` environment variables (e.g., `export TF_VAR_project_id="my-proj"`)
3. `terraform.tfvars` (or `terraform.tfvars.json`)
4. `*.auto.tfvars` (or `*.auto.tfvars.json`), processed in **alphabetical order** (so `z.auto.tfvars` overrides `a.auto.tfvars`)
5. `-var` and `-var-file` CLI flags, processed in the order passed on the command line *(highest — last flag wins)*

!!! warning "The Real-World `.tfvars` Trap"
    If `terraform.tfvars` exists in the working directory and sets `enable_gke_np = false`, editing `default = true` in `variables.tf` has **zero effect** — `terraform.tfvars` outranks `default`. Also note: if a variable has no `default` and no source supplies it, `terraform plan` hangs waiting for interactive stdin in CI unless `-input=false` is set.

### 3. Type Constraints (`list` vs. `set` vs. `object`)

- **Primitives:** `string`, `number`, `bool` (auto-converted where unambiguous, e.g., `"1"` ↔ `1`).
- **`list(T)`:** ordered, 0-indexed, allows duplicates → pairs with `count`.
- **`set(T)`:** unordered, unique elements only, no numeric indexing → required when passing a list of strings to `for_each` (or convert via `toset(var.list)`).
- **`map(T)`:** key-value pairs of uniform value type `T`.
- **`object({ attr = type, opt = optional(string, "default") })`:** strongly typed schema for module inputs (`map(object({...}))` is the standard production pattern for `for_each` over modules).

### 4. Input `validation {}` Blocks

- Evaluated during `validate`/`plan` **before** any provider API calls.
- Can only reference the variable being validated (`var.<self>`). Use `contains()`, `can(regex(...))`, or length bounds to fail fast on typos before a 15-minute cloud apply starts.

### 5. `sensitive = true` is CLI Masking, NOT Encryption

- Setting `sensitive = true` on a `variable` or `output` redacts the value as `(sensitive value)` in terminal stdout and CI logs, and taints any derived expression so you must explicitly mark downstream outputs `sensitive = true` as well.
- **It does NOT encrypt or redact the value in `terraform.tfstate`.** The raw secret is written in plaintext JSON into the state file and into any resource attribute consuming it.
- **Architectural Rules for Secrets:**
    1. Never create `google_service_account_key` in Terraform (writes a permanent private key into state); use **Workload Identity** instead.
    2. Never commit `terraform.tfstate` or secret-bearing `.tfvars` files.
    3. Store secret payloads out-of-band in Secret Manager / Vault, or pass only secret resource IDs/references across modules.

### 6. Volatile Functions (`timestamp()`, `uuid()`) Cause Perpetual Diffs

- `timestamp()` evaluates to a new value on every `plan`, preventing any resource that references it from ever converging (`~ update in-place` on every run).
- Fix with `lifecycle { ignore_changes = [...] }` on the target attribute, or use the `time_static` / `random_id` resources which persist their generated value in state once.

---

## Code Reference

=== "Local (`01-basics/2-variable-locals` & Validation/Sensitive)"

    ```hcl
    variable "name_length" {
      description = "Length of the random pet name"
      type        = number
      default     = 2

      validation {
        condition     = var.name_length >= 1 && var.name_length <= 5
        error_message = "name_length must be between 1 and 5."
      }
    }

    variable "api_token" {
      type      = string
      default   = "super-secret-value-123"
      sensitive = true # Masks stdout only — still plaintext in terraform.tfstate!
    }

    locals {
      base_dir         = "/tmp/tf-practice"
      timestamp_suffix = formatdate("YYYYMMDD", timestamp()) # Volatile!
    }

    resource "local_file" "config" {
      filename = "${local.base_dir}/app-config.txt"
      content  = "token=${var.api_token}\ngenerated=${local.timestamp_suffix}"

      lifecycle {
        ignore_changes = [content] # Prevents perpetual diff from timestamp()
      }
    }
    ```

    ```bash
    # Prove validation fails at plan time before touching disk/API
    terraform plan -var="name_length=10"

    # Prove sensitive=true still writes plaintext into state
    terraform apply -auto-approve
    grep -o 'super-secret[^"]*' terraform.tfstate
    ```

=== "GCP Locals & Org Policy Gotcha (`02-gcp-terraform/z-core-gcp-resources`)"

    ```hcl
    # variables.tf
    variable "project_id" {
      type    = string
      default = "default-fallback-project" # Overridden by terraform.tfvars
    }

    variable "environments" {
      type    = set(string)
      default = ["dev", "staging"]
    }

    # locals.tf
    locals {
      name_prefix = "acme"
      common_labels = {
        project     = var.project_id
        managed_by  = "terraform"
        environment = "sandbox"
      }
    }

    # resources.tf
    resource "google_storage_bucket" "demo" {
      name     = "${local.name_prefix}-demo-${var.project_id}"
      location = "US"
      labels   = local.common_labels

      # GCP Gotcha: When apply fails with `Error 412: constraints/storage.uniformBucketLevelAccess`,
      # it is a GCP Organization Policy constraint, not a Terraform bug. The provider defaults
      # this field to `false`; set it explicitly to satisfy the org policy:
      uniform_bucket_level_access = true
    }
    ```
