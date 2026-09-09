---
primary_color: '#007bff'
---

# Quiz — Variables, Expressions & Guards

<!-- mkdocs-quiz intro -->
Variable precedence, and the `count`/`for_each` guard patterns that decide whether a resource exists at all. The last three questions are all the same underlying trap: a guard protects only what it directly wraps.

**6 questions.** [Back to all topics](index.md)

<!-- source: session-02 -->
<quiz>
You edit a variable's `default` value in variables.tf, but terraform.tfvars already sets that same variable. Which value does Terraform actually use?
- [ ] The new default — defaults always win for clarity
- [ ] Whichever was set most recently by file modification time
- [x] The terraform.tfvars value — it sits higher in the precedence order than defaults
- [ ] Terraform errors out on the conflict
Precedence low to high: default in variables.tf < terraform.tfvars < *.auto.tfvars < -var-file < -var flag < TF_VAR_* env vars. A .tfvars file silently overrides an edited default — a genuinely common real-world gotcha that can waste real debugging time if you don't know the order.
</quiz>

<!-- source: session-02 -->
<quiz>
A repo has `local.static_envs = ["dev", "qa"]` and separately a `var.static_env` boolean that controls review-environment behavior. Does Terraform automatically ensure these two stay consistent (e.g. that running on the 'dev' workspace automatically sets static_env = true)?
- [ ] Yes, workspace names are automatically cross-referenced against any list containing them
- [x] No — static_envs is purely descriptive and never actually checked against terraform.workspace; static_env is a separate, manually-set value with no automatic connection
- [ ] Only if the list is named exactly 'static_envs'
- [ ] Yes, but only in Terraform 1.7+
A real, easy-to-miss design gap: static_envs existing as a list of strings doesn't mean anything checks terraform.workspace against it. Whoever applies the dev/qa workspaces is expected to remember to also set static_env = true manually. Forget it, and 'dev' silently gets treated as an ephemeral review environment. Naming conventions in Terraform are never automatically enforced unless code explicitly wires them together.
</quiz>

<!-- source: session-02 -->
<quiz>
One local value is wrapped in try(..., "") with a null-check before use (feeding a graceful mock-data fallback). A different local value in the same repo calls jsondecode directly with no guard, and fails loudly if the upstream data is missing. Is the unguarded one necessarily worse code?
- [ ] Yes — every external data read should always be guarded defensively
- [x] No — it depends on whether the dependency is genuinely optional (with a real fallback) or a hard prerequisite the system can't meaningfully run without
- [ ] Yes, because unguarded code always indicates the original author made a mistake
- [ ] No, guards should never be used in production Terraform
In this case: an optional database dependency had a real mock-data fallback, so a guard made sense there. An SSO/auth secret had no meaningful fallback — failing fast and loud when it's missing is the CORRECT design, not a shortcut. Blanket-wrapping every read in try() would hide a real prerequisite failure behind a confusing downstream error instead of surfacing it immediately.
</quiz>

<!-- source: session-02 -->
<quiz>
A local value filters out entries whose upstream dependency doesn't exist yet, e.g. `{ for k, v in x : k => v if condition }`. Two other resources elsewhere in the same repo still do `for_each = toset(local.full_unfiltered_list)` and then index into the now-filtered map directly. What happens?
- [ ] Terraform automatically applies the same filter to every for_each in the repo
- [ ] Nothing — filtering one local protects the whole repo
- [x] The same 'invalid index' error just resurfaces in those other resources — a guard only protects what it directly wraps
- [ ] Terraform throws a compile-time warning about the mismatch
This is a real, easy-to-miss pattern: guarding a local's own computation does nothing for a separate for_each elsewhere that iterates the ORIGINAL unfiltered list and indexes into the filtered map. Every downstream consumer needs either the same filtered key-set for its own for_each, or its own independent guard — otherwise the failure just moves one file downstream, and looks like a brand new bug rather than the same root cause.
</quiz>

<!-- source: session-02 -->
<quiz>
A resource has `count = local.some_condition ? 1 : 0`. When the condition is false, what actually happens to that resource?
- [ ] It's created with all attributes set to empty/null values
- [x] It doesn't get created at all — count turns the resource into a zero-length LIST of instances, and index [0] doesn't exist
- [ ] It's created but marked disabled
- [ ] Terraform throws a plan-time error unless the condition is always true
count = 0 means zero instances exist — not that one instance exists with empty values. count also implicitly turns the resource into a list, even with only one possible instance, so referencing resource[0] when count=0 would error unless wrapped in try(). This is exactly why try(resource[0].result, "") shows up in real code guarding count-conditional resources.
</quiz>

<!-- source: session-02 -->
<quiz>
A module block uses for_each over a map filtered down to only enabled entries: `for_each = { for k, v in x : k => v if v.enabled }`. If both entries in the map are disabled, what does `for_each`-over-modules actually do?
- [ ] Errors, since for_each over modules requires at least one entry
- [x] Creates zero instances of that module — an empty map means an empty for_each, no error
- [ ] Falls back to creating exactly one instance with default values
- [ ] Requires a separate count = 0 guard in addition to for_each
for_each over an empty map/set simply creates nothing — no error, no fallback. This is exactly how a GKE-cluster module block can safely default to creating zero clusters when both environment-enable flags are false, letting terraform plan succeed cleanly without any resources being created.
</quiz>

<!-- mkdocs-quiz results -->
