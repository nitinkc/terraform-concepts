# 1 — Resources and state

**Folder:** [`01-basics/1-create-local-file/`](https://github.com/nitinkc/terraform-concepts/tree/main/01-basics/1-create-local-file)

A `resource` is something Terraform owns for its whole lifecycle. It creates it, notices
when it drifts, and destroys it on `terraform destroy`. That ownership is recorded in the
**state file** — Terraform's ledger mapping config addresses to real things.

## The code

```hcl
resource "local_file" "pet" {
  filename        = "/tmp/hello.txt"
  content         = "Hello! Let the terraform learning commence...."
  file_permission = "0700"
}
```

## Run it

```bash
terraform init && terraform apply
cat /tmp/hello.txt
terraform state list     # local_file.pet — Terraform now has a record of it
terraform destroy        # the file is gone
```

## The two experiments that matter

These two look similar and behave completely differently. Run both.

**Delete the file, keep the state:**

```bash
terraform apply
rm /tmp/hello.txt
terraform plan     # Terraform detects the drift and offers to recreate it
```

Terraform compares state against reality during the refresh step, sees the file is gone,
and plans to recreate it. This is drift detection doing its job, not magic.

**Delete the state, keep the file:**

```bash
terraform apply
rm terraform.tfstate
terraform plan     # Terraform has no memory of the file and plans to create it fresh
```

Terraform has no idea the file exists. It will not go looking for it — there is no
reconciliation pass that scans the world for things that might be yours. It plans a
create, and on apply it silently clobbers the existing file.

**That silent clobber is provider-specific and worth remembering.** A cloud API usually
protects you here: `google_service_account` rejects a duplicate `account_id` with an
"already exists" error rather than overwriting. `local_file` has no such protection. Don't
assume every provider fails safe — see [State surgery](12-state-surgery.md).

## Key takeaway

State is the *only* thing connecting your config to reality. Lose it and Terraform doesn't
search for orphans, it just tries to create again. Adoption of an existing resource is
always explicit — see [`terraform import`](12-state-surgery.md).

---

Theory: [§4 Resources and state](../theory/04-resources-and-state.md) ·
Quiz: [Resources, state & drift](../quiz/02-resources-state-and-drift.md) ·
Next: [Variables](02-variables.md)
