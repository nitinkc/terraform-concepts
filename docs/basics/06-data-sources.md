# 6 — Data sources

**Folder:** [`01-basics/6-data-sources/`](https://github.com/nitinkc/terraform-concepts/tree/main/01-basics/6-data-sources)

A `data` block *reads* something Terraform doesn't own. No create, no update, no destroy —
and it re-queries live on every single `plan`/`apply` rather than serving a value cached in
state.

## The code

```hcl
resource "local_file" "pet" {
  filename        = "/tmp/hello.txt"
  content         = data.local_file.my_file.content
  file_permission = "0700"
}

data "local_file" "my_file" {
  filename = "/tmp/my_file.txt"
}
```

## Run it

`/tmp/my_file.txt` doesn't exist yet, and a data block will never create it:

```bash
echo "read by a data source" > /tmp/my_file.txt
terraform init && terraform apply
cat /tmp/hello.txt                # contents copied from the data source
```

## The experiment — same missing file, opposite behaviour

This is the whole point of the topic.

```bash
rm /tmp/my_file.txt
terraform plan     # errors: there is nothing to read
```

Now compare with deleting `/tmp/hello.txt`, which is a `resource`:

```bash
rm /tmp/hello.txt
terraform plan     # calmly offers to recreate it
```

Same missing file, opposite behaviour, because ownership differs. A resource that has gone
missing is drift Terraform will fix. A data source that has gone missing is an error,
because Terraform has no authority to create it.

This is the distinction [Theory §11](../theory/11-data-sources.md) describes,
and the one that got answered wrong in [Session 1](../sessions/session-01.md).

## Destroy never touches what a data block reads

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
terraform apply
terraform output external_file_content
terraform destroy
cat /tmp/external-file.txt   # still there
```

Only Terraform-*managed* resources get deleted on destroy. The GCP equivalent behaves
identically — see [Lab 7](../gcp/02-lab-notes.md#lab-7-data-sources) and
[`data.tf`](../gcp/01-core-root.md) in the core GCP root, which reads a project and a
network that Terraform didn't create.

## Key takeaway

Data sources show as reads in `plan`, never as create or destroy. Use them to reference
infrastructure you don't own in this config — an existing network, another team's project,
a value another repo published — instead of hardcoding IDs.

---

Theory: [§11 Data sources](../theory/11-data-sources.md) ·
Quiz: [Resources, state & drift](../quiz/02-resources-state-and-drift.md) ·
Next: [count and for_each](07-count-and-for-each.md)
