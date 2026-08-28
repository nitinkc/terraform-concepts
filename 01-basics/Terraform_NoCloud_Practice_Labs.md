# Terraform — No-Cloud Practice Labs (local_file / random / null / tls)

> Zero GCP auth required. Everything runs against your local filesystem via the `local`,
> `random`, `null`, and `tls` providers — real Terraform lifecycle mechanics, no cloud
> account needed. Builds on your existing `01-create-file.tf` / `main.tf` / `variable.tf`
> sandbox. Each exercise = concept + starter code + what to run + what to check.

Suggested folder: `00-nocloud-basics/` — one subfolder per numbered exercise, or all in one
folder if you don't mind resetting between exercises (`terraform destroy` between each is
fine here, nothing costs money or needs cleanup approval).

---

## What You Already Have (confirmed working)

- **Resource creation** — `local_file.pet` writing a file to disk.
- **Implicit dependency** — `local_file.pet` references `random_pet.my_pet.id` in its
  `content`, so Terraform creates the pet name before writing the file.
- **Variables with type + default** — `fileName`, `prefix`, `separator`, `name_length`.
- **`terraform graph`** — you generated `graph.svg` showing the dependency edge between
  `local_file.pet` and `random_pet.my_pet`. (Command: `terraform graph | dot -Tsvg > graph.svg`
  — requires Graphviz's `dot` installed locally.)

Gap already worth noting: your `variable.tf` declares a `content` variable, but `main.tf`
never uses `var.content` — it hardcodes the content string instead. Small inconsistency,
harmless here, but a good habit check: **an unused declared variable is a smell** — either
wire it up or remove it. Exercise 1 below fixes this.

---

## Exercise 1 — Wire up the unused variable + `count`

**Goal:** fix the dangling `var.content`, then create multiple files at once with `count`.

```hcl
resource "local_file" "pet" {
  filename = var.fileName
  content  = var.content
}

resource "local_file" "multi" {
  count    = 3
  filename = "/tmp/pet-${count.index}.txt"
  content  = "This is pet file number ${count.index}"
}
```

```bash
terraform plan
terraform apply
ls /tmp/pet-*.txt
cat /tmp/pet-1.txt
terraform state list
```

**Check:** `terraform state list` shows `local_file.multi[0]`, `[1]`, `[2]` — three separate
addressable instances from one block.

**Extra credit:** change `count = 3` to `count = 1`, re-plan. Confirm Terraform proposes
destroying `multi[1]` and `multi[2]` — indices beyond the new count are removed, exactly
like the GCP `count` lab, just against local files instead of service accounts.

---

## Exercise 2 — `for_each` with local files (stable-key version of Exercise 1)

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
terraform plan
terraform apply
terraform state list
```

**Check:** addresses are `local_file.named_pets["fido"]` etc — keyed, not indexed.

**Extra credit — the destructive test:** remove `"whiskers"` from the set, re-plan. Confirm
**only** `named_pets["whiskers"]` is destroyed — `"fido"` and `"rex"` are untouched. Contrast
this with Exercise 1's `count` behavior above — this is the exact bug `for_each` fixes.

---

## Exercise 3 — `locals` (computed values)

```hcl
locals {
  timestamp_suffix = formatdate("YYYYMMDD", timestamp())
  base_dir          = "/tmp/tf-practice"
  full_greeting     = "Hello from ${var.prefix}! Generated on ${local.timestamp_suffix}."
}

resource "local_file" "computed" {
  filename = "${local.base_dir}/greeting-${local.timestamp_suffix}.txt"
  content  = local.full_greeting
}
```

```bash
mkdir -p /tmp/tf-practice
terraform plan
terraform apply
cat /tmp/tf-practice/greeting-*.txt
```

**Note the `timestamp()` function:** it changes every run. Re-run `terraform plan`
immediately after apply with no other changes — Terraform will still show a diff on any
resource referencing `timestamp()`-derived values, because that function re-evaluates every
plan. **Key lesson:** functions like `timestamp()` make a resource perpetually "different" —
a good example of why volatile functions are used carefully in real configs (usually
wrapped with `ignore_changes` if the drift shouldn't matter).

---

## Exercise 4 — Outputs (primitive + structured)

```hcl
output "pet_id" {
  description = "The generated random pet name/id."
  value       = random_pet.my_pet.id
}

output "all_named_pet_files" {
  description = "Map of pet name to file path."
  value       = { for k, f in local_file.named_pets : k => f.filename }
}
```

```bash
terraform apply
terraform output pet_id
terraform output -raw pet_id
terraform output -json all_named_pet_files
terraform output -json all_named_pet_files | jq -r '.fido'
```

**Check:** `-raw` works on `pet_id` (primitive) but would error on `all_named_pet_files`
(structured) — same distinction as the GCP service-account-email lab.

---

## Exercise 5 — Data source (read something Terraform didn't create)

The `local` provider has a read-only counterpart: `data "local_file"`.

```bash
echo "pre-existing content, not managed by terraform" > /tmp/external-file.txt
```

```hcl
data "local_file" "external" {
  filename = "/tmp/external-file.txt"
}

output "external_file_content" {
  value = data.local_file.external.content
}
```

```bash
terraform plan
terraform apply
terraform output external_file_content
terraform destroy
cat /tmp/external-file.txt   # confirm it still exists — data sources are read-only
```

**Check:** `terraform destroy` does NOT delete `/tmp/external-file.txt` — only
Terraform-*managed* `local_file` resources get deleted on destroy. Directly parallels the
GCP data-source lab (destroy never touches what a `data` block only reads).

---

## Exercise 6 — Conditionals + `count = 0/1` (the gap you flagged earlier)

```hcl
variable "create_backup_file" {
  type    = bool
  default = false
}

resource "local_file" "backup" {
  count    = var.create_backup_file ? 1 : 0
  filename = "/tmp/backup.txt"
  content  = "This only exists if the flag is true."
}
```

```bash
terraform plan     # with default false — 0 resources, nothing created
terraform plan -var="create_backup_file=true"   # now shows 1 to add
```

**Try referencing it wrong on purpose** to see the exact error from before:
```hcl
output "backup_path" {
  value = local_file.backup.filename   # WRONG when count is used — no index given
}
```
Run `terraform plan` — expect an error about needing an index, e.g.
`local_file.backup[count.index]`. Fix it:
```hcl
output "backup_path" {
  value = length(local_file.backup) > 0 ? local_file.backup[0].filename : "not created"
}
```

**Check:** confirms exactly what happens when `count = 0` — the resource becomes an
**empty list of instances**, not a single resource with empty values (your previously
logged knowledge gap on this — this is the concrete, hands-on fix for it).

---

## Exercise 7 — `dynamic` blocks (no cloud equivalent needed — use `null_resource` triggers)

```hcl
locals {
  greetings = {
    en = "Hello"
    fr = "Bonjour"
    es = "Hola"
  }
}

resource "local_file" "multi_lang" {
  for_each = local.greetings
  filename = "/tmp/greeting-${each.key}.txt"
  content  = each.value
}

resource "null_resource" "print_all" {
  triggers = {
    file_count = length(local.greetings)
  }

  provisioner "local-exec" {
    command = "echo Created ${self.triggers.file_count} greeting files"
  }
}
```

```bash
terraform apply
```

**Check:** the `local-exec` output prints during apply. `null_resource` has no real cloud
backing — it exists purely to trigger provisioners or hold `triggers` values that force
re-evaluation. Good, safe way to practice provisioners without touching real infrastructure
(same mechanism flagged as a security risk in CI/CD contexts — worth remembering *why* it's
powerful/dangerous even in this harmless local form).

---

## Exercise 8 — Variable validation

```hcl
variable "name_length" {
  description = "The length of the random pet name"
  type        = number
  default     = 1

  validation {
    condition     = var.name_length >= 1 && var.name_length <= 5
    error_message = "name_length must be between 1 and 5."
  }
}
```

```bash
terraform plan -var="name_length=10"
```

**Check:** plan fails immediately with your custom error message, before Terraform even
attempts a provider call. Validation blocks catch bad input at the config layer — useful for
enforcing constraints teammates might not know about (e.g. naming conventions, allowed
ranges) without waiting for a cryptic provider-level API error.

---

## Exercise 9 — Sensitive variables

```hcl
variable "api_token" {
  description = "A fake secret, for practicing sensitive handling."
  type        = string
  default     = "super-secret-value-123"
  sensitive   = true
}

resource "local_file" "config" {
  filename = "/tmp/app-config.txt"
  content  = "token=${var.api_token}"
  # sensitive value flows into the file content — Terraform will warn about this
}
```

```bash
terraform plan
```

**Check:** Terraform's plan output masks `var.api_token`'s value directly, but note the
**file itself, once written, still contains the raw secret in plaintext** — `sensitive`
protects CLI/plan output, not the actual artifact on disk. Direct hands-on proof of the
"masking ≠ encryption" lesson from the theory reference — try `cat /tmp/app-config.txt`
after apply to see the real value sitting there in plain text.

---

## Exercise 10 — State surgery, fully local (mv / rm / import)

**10a — Rename without destroy:**
```bash
# rename local_file.pet -> local_file.greeting_file in your code first, then:
terraform state mv local_file.pet local_file.greeting_file
terraform plan   # should show no changes
```

**10b — Remove from state, file untouched:**
```bash
terraform state rm local_file.greeting_file
ls -la /tmp/helloFruits.txt   # still exists on disk
terraform plan                 # now wants to "create" — will conflict/overwrite silently,
                                # since local_file has no natural "already exists" API error
                                # like GCP does — worth noticing this difference!
```

**10c — Re-adopt via import:**
```hcl
resource "local_file" "greeting_file" {
  filename = "/tmp/helloFruits.txt"
  content  = "Hello World! Default Text coming from the variable"
}
```
```bash
terraform import local_file.greeting_file /tmp/helloFruits.txt
terraform plan   # compare content field for drift
```

**Important local-provider nuance to notice:** unlike `google_service_account` (which
rejects duplicate `account_id` with an API error), `local_file` will happily **overwrite**
an existing file with no conflict error if state doesn't know about it. This is a valuable
contrast — cloud APIs often protect you from Exercise 6-style "state loss + apply" disasters
with a hard error; some resource types (like local files) will not, and will just silently
clobber. Good instinct-building: **don't assume every provider protects you the same way.**

---

## Exercise 11 — Lifecycle meta-arguments

```hcl
resource "local_file" "protected" {
  filename = "/tmp/do-not-delete.txt"
  content  = "This file is protected."

  lifecycle {
    prevent_destroy = true
  }
}
```

```bash
terraform apply
terraform destroy   # should fail with a prevent_destroy error
```

Then practice `ignore_changes`:
```hcl
resource "local_file" "ignore_demo" {
  filename = "/tmp/ignore-demo.txt"
  content  = "original content"

  lifecycle {
    ignore_changes = [content]
  }
}
```
```bash
terraform apply
echo "manually changed content" > /tmp/ignore-demo.txt
terraform plan   # should show NO changes, despite the file content now differing
```

---

## Exercise 12 — `archive_file` (bonus, zero-cloud, genuinely useful)

The `archive` provider zips files — a real pattern used when preparing deployment packages
(e.g. Cloud Function source zips) but entirely local/offline here.

```hcl
terraform {
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

data "archive_file" "bundle" {
  type        = "zip"
  source_dir  = "/tmp/tf-practice"
  output_path = "/tmp/tf-practice-bundle.zip"
}

output "bundle_hash" {
  value = data.archive_file.bundle.output_md5
}
```

```bash
terraform init
terraform apply
unzip -l /tmp/tf-practice-bundle.zip
```

**Why this matters:** this is exactly the pattern real GCP repos use before deploying Cloud
Functions or similar — zip source locally, reference the zip's hash as a trigger for
redeployment when source changes. Good bridge exercise between "toy local lab" and "real
repo pattern," still without touching the cloud.
