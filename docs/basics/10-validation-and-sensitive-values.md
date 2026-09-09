# 10 — Validation and sensitive values

**Folder:** none yet — paste this into a scratch root.

Two ways of constraining a variable: one rejects bad input, the other hides the value.
Neither does what the other does, and the second one does less than its name suggests.

## Validation — reject bad input early

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

Plan fails immediately with your custom message, **before** Terraform makes a single
provider call. That's the value: the failure is instant and legible, rather than a cryptic
API error thirty seconds into an apply.

Use it for constraints a teammate wouldn't know about — naming conventions, allowed
regions, ranges the downstream API silently truncates.

## Sensitive — masking, not encryption

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
}
```

```bash
terraform plan
```

Terraform masks the value in plan output and marks the resource attribute as sensitive
because a sensitive value flowed into it. Then:

```bash
terraform apply
cat /tmp/app-config.txt        # token=super-secret-value-123, in plaintext
grep -o 'super-secret[^"]*' terraform.tfstate
```

**The secret is sitting there in plain text in both the artifact and the state file.**

`sensitive = true` controls one thing: whether the value is printed in CLI and plan output.
It does not encrypt the value, does not keep it out of state, and does not stop it landing
in whatever the resource writes.

## What follows from that

- **State is a secret.** If any sensitive value has ever passed through your config, the
  state file must be treated with the same care as the secret itself. That's the real
  argument for a remote backend with restricted IAM and encryption at rest, covered in
  [Theory §14](../theory/14-backends-and-state-security.md) and set up in
  [Lab 2](../gcp/02-lab-notes.md#lab-2-remote-state-gcs-backend).
- **`sensitive` is for shoulder-surfing and CI logs**, which is genuinely useful — a plan
  posted to a PR comment shouldn't leak a token. It is not a security boundary.
- Real secrets belong in Secret Manager or Vault, referenced by a `data` block at apply
  time, so the value is never in the config. The sandbox does this in
  `infrastructure/infra/secrets.tf`.

---

Theory: [§7 Variables](../theory/07-variables-and-locals.md),
[§14 State file security](../theory/14-backends-and-state-security.md) ·
Next: [Provider versions](11-provider-versions.md)
