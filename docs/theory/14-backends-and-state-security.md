# 14 — Backends and state security

**Assumes:** [State lifecycle](13-state-lifecycle.md).

A **backend** is where state is stored: local disk by default, or GCS/S3/Terraform Cloud.
The choice is usually framed as a collaboration decision. It is really a security decision.

## Critical misconception: `sensitive` is not encryption

**Myth:** `sensitive = true` encrypts the value.

**Reality:** it is purely a display-masking feature for stdout. The plaintext value is
still written into `terraform.tfstate`, because Terraform needs the real value to diff
against reality on future runs — it cannot do that with an irreversibly hashed value.

**Local state is plaintext, always.** By default `terraform.tfstate` is unencrypted JSON on
disk. Anyone who can read the file can read every secret in it, `sensitive` flag or not.

Why doesn't Terraform just encrypt local state? It would need a key management strategy.
Storing the key next to the file defeats the purpose; prompting for a password on every
command is unusable. Local state has no good answer — the real fix is **not to use local
state for anything real.**

## What a remote backend actually buys you

```hcl
terraform {
  backend "gcs" {
    bucket = "my-tf-state"
    prefix = "core/"
  }
}
```

| Property | Local | GCS backend |
|---|---|---|
| Encryption at rest | none | Google-managed or CMEK |
| Access control | filesystem permissions on a laptop | IAM on the bucket |
| Concurrent applies | silent corruption | state locking |
| History / recovery | whatever you remembered to copy | object versioning |
| Survives laptop loss | no | yes |

The `prefix` is how one bucket holds many configs' state; workspaces nest underneath it.
Changing the `backend` block requires `terraform init`, which offers to migrate existing
state for you. Backend blocks can't use variables — the values must be literals, which is
why environment separation is usually done with `-backend-config` at init time or separate
directories.

## The read-access constraint

`terraform plan` **requires** read access to the state file — there is no way around it,
because without it Terraform can't know what already exists (the same blank-memory problem
as [state loss](13-state-lifecycle.md)).

Therefore: **anyone who can run `plan` against a backend can, in principle, read every
secret in that state.** There is no IAM configuration that grants "run plan" without
granting "read state". That single fact is the entire argument for
[moving execution off laptops](16-gitops-and-cicd.md).

## Practical consequences

- **State is a secret.** If any sensitive value has ever passed through your config, treat
  the state file with the same care as the secret itself.
- **Don't put secrets in Terraform at all where you can avoid it.** Reference them from
  Secret Manager or Vault via a [`data` block](11-data-sources.md) at apply time, so the
  value is fetched when needed and never persisted by you.
- **A generated key is worse than a referenced one.** A `google_service_account_key`
  resource puts a permanent private key into state; Workload Identity avoids the key
  existing at all.
- **Restrict the bucket, and audit it.** Read access to the state bucket is a production
  credential, not developer convenience.

## Key takeaway

`sensitive` protects a terminal. A backend protects the data. If you only change one thing
about a config after reading this section, make it the backend.

---

Labs: [Validation and sensitive values](../basics/10-validation-and-sensitive-values.md),
[Lab 2](../gcp/02-lab-notes.md#lab-2-remote-state-gcs-backend) ·
Next: [Cross-config composition](15-cross-config-composition.md)
