# Terraform — Theory & Definitions Reference

## 1. Core Mechanics — Providers, Resources, State

**Provider** — A plugin that translates HCL into actual cloud API calls. Terraform core
knows nothing about GCP/AWS/etc. — all provider-specific logic (how to create a service
account, what fields are valid) lives in the provider binary (e.g. `hashicorp/google`).

**`required_providers` vs `provider {}` block:**

| Block                                        | Purpose                                              | Read during      |
|:---------------------------------------------|:-----------------------------------------------------|:-----------------|
| `required_providers` (inside `terraform {}`) | *Which* plugin, *where* from, *which version*        | `terraform init` |
| `provider "google" {}`                       | *How* to configure it — project, region, credentials | `plan` / `apply` |

**Resource** — A block Terraform **owns and manages** the full lifecycle of
(create/update/delete). 
> **Declarative**: you describe the desired end state, not the steps to
get there.

**State file (`terraform.tfstate`)** — Terraform's internal record mapping your HCL
resource addresses (`resource_type.local_name`) to real-world cloud resource IDs. This is
the **only** mechanism by which Terraform knows "this resource in my code = this specific
thing in the cloud."

**Why state exists (three reasons):**
1. **Identity/ownership mapping** — GCP has no concept of "this resource belongs to this
   Terraform config." State is that missing link.
2. **Performance** — querying every resource's live API state on every command would be
   slow and could hit rate limits at scale.
3. **Metadata** — dependency info and some computed values aren't always fully
   re-derivable from a live API query alone.

**Declarative vs imperative:** `gcloud` commands are imperative (you say the steps).
Terraform is declarative (you say the end state; Terraform diffs current vs. desired and
figures out the steps).

---

## 2. Resource Identity & Change Behavior

**Resource address** = `resource_type.local_name` (e.g. `google_service_account.gsa`).
This address — not any attribute inside the block — is what Terraform uses as identity in
state.

**Renaming a resource in code (without `state mv`):** Terraform sees the old address
missing from config (→ destroy) and a new address with no state entry (→ create). It does
**not** infer "this is the same thing, just renamed." 

**Fix**: `terraform state mv <old> <new>`
before/instead of just editing the code, to preserve the real resource without
destroy+recreate.

**Types of changes on `plan`:**

| Change type | Example | Behavior |
|---|---|---|
| In-place update | `display_name` on a service account | Provider PATCHes the field; resource ID unchanged |
| Force replacement ("Force New") | `account_id` on a service account | Provider can't mutate this field via the API — Terraform destroys then recreates |

Whether an attribute is in-place-updatable or force-new is defined by the **provider**, not
by Terraform core — it reflects real API constraints of the underlying cloud service.

---

## 3. Data Sources vs. Resources

**`data` block** — Read-only query. Fetches info about something that exists, but does
**not** create/update/delete it. Can point at something created manually, by another team,
or by a completely separate Terraform config/state.

| | `resource` | `data` |
|---|---|---|
| Lifecycle | Owned (create/update/delete) | Read-only |
| `terraform destroy` effect | Deletes the real thing | Only forgets it locally; real thing untouched |
| Refresh behavior | Refreshed to detect drift | Re-queried live on every `plan`/`apply` |

**Rule of thumb:** if this specific config should be responsible for the resource's
lifecycle → `resource`. If it just needs to *read* something owned elsewhere → `data`.

**Architectural implication (multi-repo pattern):** splitting resource ownership across
repos (Repo A owns the DB as a `resource`, Repo B reads DB connection info via a `data`
block) allows multiple independent consumers to share info about one owned thing without
each needing write/manage permissions on it, and without direct state coupling.

**Two ways to read across repo/config boundaries:**

1. **Shared KV store (e.g. Consul)** — Repo A publishes non-sensitive values (IP, port) to
   Consul; Repo B reads via `data "consul_keys"`. Repo B never touches Repo A's actual state
   file, so sensitive values that stay only in Repo A's state (e.g. DB password) are never
   exposed to Repo B.
2. **`terraform_remote_state` data source** — Repo B reads Repo A's state file directly
   from its backend (e.g. GCS). Simpler (no extra KV infra), but couples Repo B to Repo A's
   **entire** state file, including anything sensitive stored there — larger security
   surface.

**Trade-off summary:** Consul/KV-style = better security isolation, added
operational dependency (a separate system to keep up). `terraform_remote_state` = simpler
ops, weaker isolation (broad read access to another config's full state).

**Refresh-time dependency risk:** every `plan`/`apply` re-queries `data` sources live. If
the source (e.g. Consul) is down, the query fails and the plan **fails** — Terraform does
not silently fall back to a "last known good" cached value from state by default.
Escape hatch: `terraform plan -refresh=false` — skips live refresh, trusts state's current
cached values. Useful for emergencies, not a routine practice.

---

## 4. Variables & Locals

**Variable (`variable {}`)** — External input, like a function argument. Set from outside
the code: CLI flag, `.tfvars` file, environment variable, or a `default`.

**Local (`locals {}`)** — Internal computed value, like a local variable inside a function.
Cannot be set from outside — always derived from other values (variables, other locals,
resource attributes) inside the config itself.

**When to use which:**
- Something that legitimately changes per run/user/environment (project ID, target env
  name) → `variable`.
- Something computed/derived once from other inputs, reused throughout the config (a
  name prefix, a computed environment flag like prod-vs-nonprod) → `local`.

**Declaring a variable:**
```hcl
variable "project_id" {
  description = "The name of the GCP project"
  type        = string
  default     = "my-devops-journey-502420"
}
```

### Variable precedence (highest → lowest priority)

1. **CLI flags** — `-var="project_id=..."` or `-var-file="..."`
2. **`*.auto.tfvars`** files — loaded automatically, in **alphabetical/lexicographical
   order** (so among multiple `.auto.tfvars` files, the alphabetically-last one wins for any
   overlapping variable)
3. **`terraform.tfvars`** (or `.tfvars.json`) — standard project variable file
4. **Environment variables** — prefixed `TF_VAR_<name>` (e.g. `TF_VAR_project_id`)
5. **`default`** inside the `variable` block — lowest priority, used only if nothing above
   supplies a value

Key corrections worth remembering:
- File-based inputs (`terraform.tfvars`) beat `TF_VAR_*` environment variables — files are
  considered more explicit/project-specific.
- `*.auto.tfvars` beats plain `terraform.tfvars` — auto-loaded files are treated as
  higher-priority automated overrides.
- Among multiple `*.auto.tfvars` files, they load in alphabetical order, and **later
  (alphabetically last) wins**.

---

## 5. `terraform init` — What It Actually Does

Running `terraform init` in a fresh directory creates:

- **`.terraform/`** (hidden dir) — stores the actual downloaded provider plugin binaries.
- **`.terraform.lock.hcl`** — the **dependency lock file**. Records exact provider
  versions and cryptographic checksums used. Should be committed to git — guarantees
  everyone (and CI/CD) uses identical provider binaries, preventing silent breaking updates.

**Important nuance:** the lock file is committed to git, but the actual `.terraform/`
binaries are **not** (they're machine/OS-specific). A teammate who clones the repo still
must run `terraform init` themselves even with the lock file present — `init` downloads the
correct binary for *their* OS, guided by the versions/hashes the lock file specifies.
Skipping `init` and running `plan` directly → error demanding initialization.

---

## 6. State Lifecycle — Drift, Refresh, Loss, Import

**Drift** — when the real cloud resource no longer matches what's recorded in state/config
(e.g. someone manually edits it in the console).

**Refresh phase** — on every `plan`/`apply`, Terraform queries the live provider API for
each *managed* resource to check for drift, comparing three things: your HCL code, the real
world, and the state file. **HCL code always wins** — plan proposes changes to bring the
real world back in line with code, not the other way around.

**State loss scenario:** if `terraform.tfstate` is deleted but the real resource still
exists in the cloud, Terraform's memory is now blank — it does **not** rescan the cloud to
rediscover ownership. It sees the resource in your code with no matching state entry, so it
plans to **create** it. Running `apply` in this state → the cloud API rejects the request
("already exists") because the real resource is still there under the same identifying
field (e.g. `account_id`).

**Recovering from state loss / adopting an existing resource:** `terraform import`.
- Only writes to the **state file** — it does **not** generate HCL code for you.
- Workflow: (1) write a resource block in HCL as an "anchor" (can start empty/minimal),
  (2) run `terraform import <resource_address> <cloud_resource_id>` to pull the real
  resource's current attributes into state under that address.
- After import, if your HCL code's attribute values don't match what's actually in the
  cloud, the next `plan` will show an update to reconcile code vs. real world (not an
  error) — import doesn't force your code to match reality, you still own that step.

---

## 7. Outputs

**`output {}` block** — exposes a value from your config, either for human inspection
(`terraform output`) or for another system/config to consume (CI/CD pipeline,
`terraform_remote_state` reader).

**Primitive output (single value):**
```hcl
output "service_account_email" {
  description = "The email address of the created GCP service account."
  value       = google_service_account.gsa.email
}
```
→ `terraform output -raw service_account_email` gives the bare string, easy for shell
scripts (no JSON parsing needed).

**Structured/map output:**
```hcl
output "service_account" {
  value = {
    id    = google_service_account.gsa.account_id
    email = google_service_account.gsa.email
  }
}
```
→ `-raw` does **not** work on this (only works on primitives). Use:
```bash
terraform output -json service_account | jq -r '.email'
```

**Common mistake:** referencing the wrong local resource name inside an output (e.g.
`google_service_account.app` when the resource block is actually named
`google_service_account.gsa`) → "Reference to undeclared resource" error. The name inside
`value` must exactly match the resource's declared local name.

**Sensitive outputs:**
```hcl
output "service_account_private_key" {
  value     = google_service_account_key.mykey.private_key
  sensitive = true
}
```
`sensitive = true` **only masks CLI/terminal display** (`terraform apply`/`plan` will print
`<sensitive>` instead of the value). It does **not** encrypt anything.

---

## 8. State File Security — Critical Misconceptions

**Myth:** `sensitive = true` encrypts the value.
**Reality:** It's purely a UI/display masking feature for stdout. The actual plaintext
value is still written into `terraform.tfstate`, because Terraform needs the real value
to diff against reality on future runs — it can't do that with an irreversibly hashed value.

**Local state is plaintext, always.** By default, `terraform.tfstate` is unencrypted JSON
on disk. Anyone who can read the file can read every secret in it, `sensitive` flag or not.

**Why Terraform doesn't just encrypt local state automatically:** it would need a key
management strategy. Storing the key alongside the file defeats the purpose (attacker gets
both); requiring a password on every command is poor UX. Local state has no good answer to
this — the real fix is **not to use local state for anything real.**

**Production fix: remote backends.** A GCS (or similar) backend provides encryption-at-rest
(Google-managed or customer-managed KMS keys) and access control via IAM on the bucket,
instead of relying on filesystem permissions on a laptop.

**Read access constraint:** `terraform plan` *requires* read access to the state file — no
way around this, because without it Terraform can't know what already exists (same "blank
memory" problem as state loss). Anyone able to run `plan` against a backend can, in
principle, read every secret stored in that state.

---

## 9. GitOps / CI-CD Execution Model (Why & How)

**The core problem:** if developers run Terraform locally, their laptops need direct read
access to the state file (which contains secrets) — there is no IAM trick that grants
"run plan" without granting "read state."

**The fix — move execution off laptops entirely:**
1. Developer writes HCL locally but has **no** credentials to run `plan`/`apply` against
   production state.
2. Developer opens a Pull Request.
3. A CI/CD runner (GitHub Actions, GitLab CI, etc.), using a dedicated **non-human service
   account** with the necessary state/GCP permissions, executes `terraform plan` in an
   isolated environment.
4. Plan output is posted back to the PR for human review — but the human never directly
   touched the state file or held its credentials.

**New attack surface this introduces — arbitrary code execution via PR:**
Because the runner executes whatever HCL is on the PR branch, a malicious contributor can
smuggle in something like a `null_resource` with a `local-exec` provisioner that runs
arbitrary shell commands **on the trusted runner**, e.g. exfiltrating the state file to an
external server via `curl`.

**Defense-in-depth guardrails:**
- **PR approval gates** — don't auto-run the pipeline on unreviewed/untrusted branches;
  require a maintainer's explicit approval to trigger execution.
- **Read-only plan-stage service accounts** — the `plan` phase's service account should not
  have write/apply permissions (limits blast radius, though doesn't stop read/exfiltration).
- **Network isolation** — runners in a private VPC/restricted egress, blocking outbound
  calls to arbitrary external hosts (stops the `curl`-to-attacker-server exploit).

**Residual risk even with network isolation — build log exfiltration:** a malicious PR can
simply `cat` or `echo` the state file / secret env vars to stdout; CI systems capture stdout
into (often public-to-the-repo) build logs, leaking secrets there instead of over the
network.

**Mitigation — secret masking/redaction:** CI platforms (GitHub Actions, GitLab CI, etc.)
register known secret values (e.g. from encrypted CI secrets storage) and scan stdout in
real time, replacing literal matches with `***`/`[MASKED]`.
**Known limitation:** masking is literal string matching — trivially bypassed by
transforming the secret before printing (e.g. `echo $DB_PASSWORD | base64`). This is why
masking is a safety net for *accidental* leaks, not a defense against a *malicious* actor —
PR approval gates remain the primary control.

---

## 10. File Naming & Project Structure Conventions

**No true "entry point" file.** Unlike most programming languages, Terraform has no
`main()`. Running `plan`/`apply` in a directory causes Terraform to read and merge
**every** `.tf` file present into one logical configuration — order of files/filenames does
not determine execution order. You could put everything in one file and it would behave
identically.

**Dependency order is determined by the reference graph, not file layout or alphabetical
filename order.** If a subnet resource (in `subnet.tf`) references a VPC resource's
attribute (in `vpc.tf`), Terraform builds a dependency graph from that reference and creates
the VPC first — regardless of which file is "processed" in what order, and regardless of
whether the filenames would sort `subnet.tf` before `vpc.tf` alphabetically.

**Conventional file names (community convention only, not enforced by Terraform):**

| File                                              | Typical purpose                                                               |
|:--------------------------------------------------|:------------------------------------------------------------------------------|
| `providers.tf`                                    | Provider declarations, version constraints, provider config (project, region) |
| `variables.tf`                                    | Input variable declarations — the "input schema"                              |
| `main.tf`                                         | Primary resources / module calls — the human-oriented "entry point"           |
| `outputs.tf`                                      | Output declarations — the "output schema"                                     |
| `versions.tf`                                     | Sometimes split out — pins the core Terraform CLI version itself              |
| `<domain>.tf` (e.g. `iam.tf`, `gcs.tf`, `vpc.tf`) | Splitting large configs by resource domain once `main.tf` gets unwieldy       |

These are organizational conventions for human readability and team consistency — Terraform
itself is indifferent to file names or their contents' arrangement.

---

## 11. Quick-Reference Command Cheat Sheet

| Command | Purpose |
|---|---|
| `terraform init` | Download providers, set up backend, create `.terraform/` + lock file |
| `terraform plan` | Refresh + diff config vs. state vs. real world; show proposed changes |
| `terraform apply` | Execute the plan against real infrastructure |
| `terraform destroy` | Delete all resources this config manages (does not touch `data` sources' targets) |
| `terraform state list` | List all resource addresses currently tracked in state |
| `terraform state show <addr>` | Show full attributes of one tracked resource |
| `terraform state mv <old> <new>` | Rename a resource's address in state without destroy/recreate |
| `terraform state rm <addr>` | Forget a resource in state (real resource untouched, becomes unmanaged) |
| `terraform import <addr> <cloud_id>` | Map an existing real resource into state under a given address (state only, not code) |
| `terraform output` | Show all outputs |
| `terraform output -raw <name>` | Print a primitive output's bare value (no quotes) |
| `terraform output -json <name>` | Print a structured output as JSON (pipe to `jq`) |
| `terraform workspace list/new/select` | Manage isolated state per workspace |
| `terraform plan -refresh=false` | Skip live refresh of resources/data sources; use cached state values |
| `terraform plan -var="k=v"` | Override a variable value for this run only (highest precedence) |

---

## 12. Terms Glossary (fast lookup)

- **HCL** — HashiCorp Configuration Language; the `.tf` file syntax.
- **Provider** — plugin translating HCL to a specific API (GCP, AWS, etc.).
- **Resource** — a block Terraform creates/owns/destroys.
- **Data source** — a block Terraform only reads, never manages.
- **State file** — JSON ledger mapping HCL resource addresses to real cloud resource IDs.
- **Drift** — divergence between state/code and the real, live resource.
- **Refresh** — the live-API-query step Terraform performs before diffing, on `plan`/`apply`.
- **Force replacement / "Force New"** — a change requiring destroy + recreate because the
  field can't be updated in place via the provider's API.
- **Backend** — where state is stored (local disk, GCS, S3, Terraform Cloud, etc.).
- **Lock file (`.terraform.lock.hcl`)** — records exact provider versions/checksums for
  reproducibility; committed to git.
- **Workspace** — a named, isolated state file within the same config/codebase.
- **`terraform_remote_state`** — a data source type for reading another config's state
  outputs directly from its backend.
- **GitOps** — running IaC changes through a Git PR + CI/CD pipeline rather than local
  developer execution, as a security/audit boundary.
- **Secret masking/redaction** — CI/CD platforms replacing known secret values with `***`
  in build logs; defeatable by transforming the secret before printing.
