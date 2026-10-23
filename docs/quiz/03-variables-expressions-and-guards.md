---
primary_color: '#007bff'
---

# Quiz — Variables, Locals, Repetition, Outputs & Guards

<!-- mkdocs-quiz intro -->
Variable precedence, `locals` & volatile functions, `validation`, why `sensitive = true` is not encryption, `count` vs `for_each` vs `dynamic`, outputs (`-raw` vs `-json`), and downstream guard propagation. Reference: [§5 Variables & Locals](../reference/05-variables-locals-and-security.md), [§6 Expressions & Guards](../reference/06-expressions-conditionals-and-guards.md), [§7 Repetition](../reference/07-repetition-count-for-each-dynamic.md), and [§8 Data, Outputs & Modules](../reference/08-data-sources-outputs-and-modules.md).

**13 questions.** [Back to all topics](index.md)

<!-- source: session-02 -->
<quiz>
You edit a variable's `default` value in variables.tf, but terraform.tfvars already sets that same variable. Which value does Terraform actually use, and what is the true precedence order from lowest to highest?
- [ ] The new default wins; order is `terraform.tfvars < default < TF_VAR_* < -var`
- [ ] Whichever file was modified most recently wins
- [x] The `terraform.tfvars` value wins; order from lowest to highest is `default < TF_VAR_* < terraform.tfvars < *.auto.tfvars < -var / -var-file`
- [ ] Terraform errors out when both `default` and `terraform.tfvars` define the same variable
`default` is the fallback of last resort. Environment variables (`TF_VAR_*`) beat `default`, `terraform.tfvars` beats `TF_VAR_*`, `*.auto.tfvars` (alphabetically last) beats `terraform.tfvars`, and CLI `-var` / `-var-file` flags win unconditionally.
</quiz>

<!-- source: session-02 -->
<quiz>
A repo has `local.static_envs = ["dev", "qa"]` and separately a `var.static_env` boolean that controls review-environment behavior. Does Terraform automatically ensure these two stay consistent (e.g. that running on the 'dev' workspace automatically sets static_env = true)?
- [ ] Yes, workspace names are automatically cross-referenced against any list containing them
- [x] No — static_envs is purely descriptive and never actually checked against terraform.workspace; static_env is a separate, manually-set value with no automatic connection
- [ ] Only if the list is named exactly 'static_envs'
- [ ] Yes, but only in Terraform 1.7+
Naming conventions in Terraform are never automatically enforced unless code explicitly wires them together (e.g., `contains(local.static_envs, terraform.workspace)`).
</quiz>

<!-- source: session-02 -->
<quiz>
One local value is wrapped in `try(..., "")` with a null-check before use (feeding a graceful mock-data fallback). A different local value in the same repo calls `jsondecode` directly with no guard, and fails loudly if the upstream data is missing. Is the unguarded one necessarily worse code?
- [ ] Yes — every external data read should always be guarded defensively
- [x] No — it depends on whether the dependency is genuinely optional (with a real fallback) or a hard prerequisite the system can't meaningfully run without
- [ ] Yes, because unguarded code always indicates the original author made a mistake
- [ ] No, guards should never be used in production Terraform
An optional database dependency with a mock-data fallback should be guarded (`try()`). A hard prerequisite like SSO/auth secrets has no meaningful fallback — failing fast and loud at plan time is the correct design.
</quiz>

<!-- source: session-02 -->
<quiz>
A local value filters out entries whose upstream dependency doesn't exist yet, e.g. `{ for k, v in x : k => v if condition }`. Two other resources elsewhere in the same repo still do `for_each = toset(local.full_unfiltered_list)` and then index into the now-filtered map directly. What happens?
- [ ] Terraform automatically applies the same filter to every for_each in the repo
- [ ] Nothing — filtering one local protects the whole repo
- [x] The same 'invalid index' error just resurfaces in those other resources — a guard only protects what it directly wraps
- [ ] Terraform throws a compile-time warning about the mismatch
Guarding a local's computation does nothing for a downstream `for_each` that still iterates the unfiltered list and indexes into the filtered map. Define `local.available_environments = toset(keys(local.filtered_map))` and drive every downstream `for_each` from that filtered keyset.
</quiz>

<!-- source: session-02 -->
<quiz>
A resource has `count = local.some_condition ? 1 : 0`. When the condition is false, what actually happens to that resource, and how do you safely reference an attribute on it in an `output`?
- [ ] It's created with all attributes set to null; reference it as `resource.main.attr`
- [x] It becomes a zero-length list `[]` where index `[0]` does not exist; reference it safely with `one(resource.main[*].attr)` or `try(resource.main[0].attr, null)`
- [ ] It's created but marked disabled; reference it as `resource.main[0].attr`
- [ ] Terraform throws a plan-time error unless the condition is always true
`count = 0` produces a 0-element list of instances, not a nullable object. Referencing `resource.main.attr` fails because an index is required, and `resource.main[0].attr` fails when `count = 0` unless guarded by `one()`, `try()`, or `length() > 0`.
</quiz>

<!-- source: session-02 -->
<quiz>
A module block uses `for_each` over a map filtered down to only enabled entries: `for_each = { for k, v in x : k => v if v.enabled }`. If both entries in the map are disabled, what does `for_each`-over-modules actually do?
- [ ] Errors, since for_each over modules requires at least one entry
- [x] Creates zero instances of that module — an empty map means an empty for_each, no error
- [ ] Falls back to creating exactly one instance with default values
- [ ] Requires a separate count = 0 guard in addition to for_each
`for_each` over an empty map/set cleanly creates zero instances with no error. Every downstream consumer of `module.<name>` must then handle an empty map `{}`.
</quiz>

<!-- source: reference-05 -->
<quiz>
You mark `variable "api_token"` with `sensitive = true` and write it into `local_file.config`. You also reference `var.api_token` inside a normal `output "token_out"` block without `sensitive = true`. What happens?
- [ ] Terraform encrypts the token in `terraform.tfstate` and prints it in `output`
- [x] `terraform plan` fails until `output "token_out"` is also marked `sensitive = true` (contagion rule); once applied, the token is masked in CLI stdout but still stored in **plaintext** inside `terraform.tfstate` and the file on disk
- [ ] Terraform hashes the value with SHA-256 before writing `terraform.tfstate`
- [ ] `sensitive = true` prevents the variable from being used inside any `resource` block
`sensitive = true` only masks terminal/CI stdout and enforces contagion on downstream outputs so secrets aren't printed accidentally. It provides zero encryption in `terraform.tfstate`.
</quiz>

<!-- source: reference-05 -->
<quiz>
A config defines `locals { suffix = formatdate("YYYYMMDD-hhmmss", timestamp()) }` and uses `local.suffix` inside a resource's content/labels. What happens when you run `terraform plan` immediately after a successful `terraform apply`?
- [ ] `No changes` — `locals` are cached in `terraform.tfstate` between runs
- [x] `plan` proposes an update every single time (perpetual diff) because `timestamp()` is a volatile function re-evaluated on every run; fix with `lifecycle { ignore_changes = [...] }` or a `time_static` resource
- [ ] `plan` fails with an error because function calls are not allowed in `locals`
- [ ] `timestamp()` only evaluates during `terraform init`
`locals` are recomputed from scratch on every `plan`/`apply`. Volatile functions like `timestamp()` or `uuid()` produce a new value every run, preventing convergence unless ignored via `lifecycle { ignore_changes }` or replaced with a state-backed resource (`random_id`, `time_static`).
</quiz>

<!-- source: reference-07 -->
<quiz>
You create 3 GCP service accounts (`["dev", "qa", "prod"]`) using `count = length(var.envs)` and `var.envs[count.index]`. Later, you remove `"dev"` (index 0) so the list is `["qa", "prod"]`. What does `terraform plan` propose, and how would `for_each = toset(var.envs)` differ?
- [ ] Both `count` and `for_each` only destroy the `"dev"` service account
- [x] With `count`, `"qa"` shifts from `[1]` to `[0]` and `"prod"` shifts from `[2]` to `[1]`, causing Terraform to **destroy or replace the surviving service accounts**; with `for_each`, instances are keyed as `["dev"]`, `["qa"]`, `["prod"]`, so **only** `["dev"]` is destroyed
- [ ] `count` renames `[1]` and `[2]` automatically without touching GCP
- [ ] `for_each` destroys all 3 service accounts when the set changes
`count` addresses instances by numeric position (`[0]`, `[1]`, `[2]`), so removing an element from the front or middle shifts every subsequent index. `for_each` addresses instances by stable string key (`["dev"]`), isolating additions and removals to the exact key changed.
</quiz>

<!-- source: reference-07 -->
<quiz>
Why does `for_each = toset([google_compute_instance.vm_a.network_interface[0].network_ip])` fail during `terraform plan` when `vm_a` has not been created yet?
- [ ] `toset()` cannot be called on IP address strings
- [x] The `for_each` key set must be known at `plan` time so Terraform Core can construct the resource dependency graph (DAG), whereas a new VM's internal IP is `(known after apply)` — fix by keying `for_each` on static strings (e.g. `"vm_a"`) and passing the computed IP in the map value
- [ ] `for_each` cannot be used in the same file as `google_compute_instance`
- [ ] You must add `depends_on = [google_compute_instance.vm_a]` to make unknown `for_each` keys work
Terraform must know the exact number and addresses of resource instances during `plan` before making mutating API calls. Adding `depends_on` does not make a computed attribute known at plan time; always use static variable/local keys for `for_each` and put computed attributes inside the resource body/values.
</quiz>

<!-- source: reference-07 -->
<quiz>
You refactor a `google_storage_bucket` that had 3 hardcoded `lifecycle_rule {}` blocks into a single `dynamic "lifecycle_rule" { for_each = local.lifecycle_rules ... }` block with the exact same values. How does `terraform state list` change, and what does `terraform plan` show?
- [ ] `terraform state list` now shows 3 new `lifecycle_rule[0..2]` entries and `plan` recreates the bucket
- [x] `terraform state list` is completely unchanged (still 1 bucket resource) and `terraform plan` shows `No changes` — `dynamic` generates nested blocks inside a single resource, not separate resource instances
- [ ] `terraform state mv` is required whenever converting static blocks to `dynamic`
- [ ] `dynamic` creates a child module in state
Unlike resource-level `count`/`for_each`, `dynamic` operates purely inside one resource's configuration body. If the generated nested blocks match the previous static blocks, the plan is a 100% no-op.
</quiz>

<!-- source: reference-05 -->
<quiz>
When is a `validation {}` block inside a `variable` declaration evaluated, and what is its main restriction?
- [ ] Evaluated after `terraform apply` finishes; can reference any resource attribute in the root module
- [x] Evaluated during `validate`/`plan` before any provider API calls are made; the `condition` expression may only reference the variable being validated (`var.<self>`), not other variables or resources
- [ ] Evaluated during `terraform init`; can only validate `string` variables
- [ ] Evaluated by the cloud provider API; requires `depends_on`
`validation` fails fast at the start of `plan` before a single cloud API call is made. To guarantee it can always be evaluated immediately, Terraform restricts `condition` to referencing only `var.<this_variable_name>`.
</quiz>

<!-- source: reference-08 -->
<quiz>
You define a structured output `output "app_sa_emails" { value = { for k, m in module.app_sa : k => m.email } }` and run `terraform output -raw app_sa_emails` in a bash script. What happens?
- [ ] It prints all emails separated by spaces
- [x] It errors — `-raw` only works on primitive values (`string`, `number`, `bool`); for maps, lists, and objects you must use `terraform output -json app_sa_emails | jq -r '.dev'`
- [ ] It prints the JSON map on a single line
- [ ] It returns only the first key in the map
`-raw` strips quotes from a single primitive value so shell scripts can capture it cleanly. Complex types (`map`, `list`, `object`) have no unambiguous raw string representation and require `-json`.
</quiz>

<!-- mkdocs-quiz results -->
