# 11 — Provider versions

**Folder:** [`01-basics/7-version-constraints/`](https://github.com/nitinkc/terraform-concepts/tree/main/01-basics/7-version-constraints)

`required_providers` says *which* plugin, from *where*, at *what version*. It is read by
`terraform init` only. The separate `provider "local" {}` block says *how* to configure it,
and is read at `plan`/`apply`. Two different jobs, commonly confused.

## The code

```hcl
terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "> 2.4.1"
    }
  }
}

provider "local" {
  # Configuration options
}

resource "local_file" "pet" {
  filename        = "hello.txt"
  content         = "My test file!!"
  file_permission = "0700"
}
```

```bash
terraform init
cat .terraform.lock.hcl    # the version init actually resolved and pinned
```

## The operators

| Operator | Means |
|---|---|
| `= 2.4.1` | Exactly this |
| `> 2.4.1` | Anything newer — what this folder uses, deliberately loose |
| `>= 2.4.1, < 3.0.0` | Explicit range |
| `~> 2.4.1` | `>= 2.4.1, < 2.5.0` — patch updates only |
| `~> 2.4` | `>= 2.4, < 3.0` — minor updates allowed |

`~>` is the pessimistic constraint operator, and where the last digit sits changes its
meaning entirely. `~> 2.4.1` allows patches; `~> 2.4` allows minors. Getting that backwards
is a good way to be surprised by a provider major-version change.

## The lock file is what makes builds reproducible

```bash
# change the constraint to ~> 2.0
terraform init -upgrade
git diff .terraform.lock.hcl
```

Then commit the lock file. The *constraint* says what's acceptable; the *lock file* records
what was actually chosen, along with checksums. Without it committed, two machines running
`terraform init` a week apart can resolve to different provider versions from the same
config.

## A provider block isn't always needed

`required_providers` is required for every provider you use. A `provider {}` configuration
block is only needed if that provider actually needs configuring. The `local` and `random`
providers take no configuration, so their blocks are empty or absent — but they still have
to be declared in `required_providers`.

The inverse mistake shows up in the core GCP root, which
[declares the `random` provider it never uses](../gcp/01-core-root.md#things-worth-noticing).

## Deliberate defect

This folder writes `hello.txt` into the **current directory**, not `/tmp`, unlike every
other folder in this stage. The comment in `main.tf` says `/tmp`. Left in place on purpose:
a stale comment is worse than no comment, because you'll trust it.

---

Theory: [§3 `terraform init`](../theory/03-init-and-version-constraints.md) ·
Quiz: [Providers & auth](../quiz/01-providers-and-auth.md) ·
Next: [State surgery](12-state-surgery.md)
