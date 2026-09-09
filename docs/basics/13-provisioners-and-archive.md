# 13 — Provisioners and archive_file

**Folder:** none yet — paste this into a scratch root.

Two loosely related odds and ends, both genuinely useful to recognise: running arbitrary
commands during apply, and building a zip as part of a config.

## null_resource and local-exec

`null_resource` has no real backing anywhere. It exists purely to trigger provisioners or
hold `triggers` values that force re-evaluation.

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

The `local-exec` output prints during apply. Change a value in `local.greetings` and
re-apply — the `triggers` map changes, so the `null_resource` is replaced and the
provisioner runs again. Without `triggers`, it would run once and never again.

!!! note "This is not a `dynamic` block"
    This example is `for_each` over a map. A `dynamic` block is a different thing: it
    generates repeated *nested blocks inside one resource*, not repeated resources. There
    is no local-provider example in this repo, because the local providers have no nested
    blocks worth repeating. Both real ones are cloud resources: the `lifecycle_rule`
    generator in [Lab 12](../gcp/02-lab-notes.md#lab-12-dynamic-blocks) and
    [`resources.tf`](../gcp/01-core-root.md) in the core GCP root, and `dynamic "rule"` in
    the sandbox's `backend/infra/rbac.tf`.

## Why provisioners are a code smell

Modern Terraform guidance treats `local-exec` and `remote-exec` as a last resort. They run
imperative commands inside a declarative tool, they aren't tracked in state beyond "did it
run", and a failure mid-provisioner leaves the resource tainted.

Most cases are better handled by cloud-init, a startup script, or a real config-management
tool. Recognise them because they appear in older repos — and because the same mechanism is
an attack vector: a malicious PR adding a `local-exec` that exfiltrates state is the exploit
described in [Theory §16](../theory/16-gitops-and-cicd.md). This is
harmless in a `/tmp` sandbox and very much not harmless in CI with cloud credentials
attached.

The GCP version is [Lab 17](../gcp/02-lab-notes.md#lab-17-provisioners-null_resource-brief).

## archive_file

The `archive` provider zips files. Entirely local and offline, but it's a real pattern —
this is how you prepare a Cloud Function source bundle.

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

Note it's a `data` source, not a resource — it computes the zip during plan rather than
managing it as owned state.

**Why it matters:** the `output_md5` is the point. Real configs feed that hash into the
deploying resource so that changing the source automatically triggers a redeploy, without
anyone having to remember to bump a version. Good bridge between "toy local lab" and "real
repo pattern", still without touching a cloud.

## Key takeaway

Both of these are escape hatches from the declarative model, and they escape differently.
`local-exec` runs a command Terraform can't reason about, so its result lives outside the
graph — treat it as a signal to look for a better mechanism. `archive_file` escapes safely,
because what comes back is a hash that feeds *into* the graph. That's the distinction worth
keeping: whether the escape hatch hands you something Terraform can still track.

---

You've finished Stage 2. Next: **[Stage 3 — GCP](../gcp/index.md)**, where the same
mechanics run against a real project with quotas, org policies, propagation delays and a
bill.
