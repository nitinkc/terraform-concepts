# 3 — `terraform init` and version constraints

**Assumes:** [Providers and authentication](02-providers-and-authentication.md).

`init` is the only command that talks to the Terraform registry, and the only one that
writes provider binaries to disk. It is idempotent and cheap — run it whenever you're
unsure.

## What `init` creates

| Path | What it is | Committed? |
|---|---|---|
| `.terraform/` | the downloaded provider plugin binaries, plus backend config cache | **No** — machine/OS-specific |
| `.terraform.lock.hcl` | the dependency lock file: exact provider versions plus checksums | **Yes** — except in this repo, see the note below |

**The nuance that matters:** the lock file is committed, the binaries are not. A teammate
who clones the repo still has to run `init` themselves even with the lock file present —
`init` downloads the correct binary for *their* OS, guided by the versions and hashes the
lock file specifies. Skipping `init` and running `plan` directly gives you an error
demanding initialization.

`init` also configures the [backend](14-backends-and-state-security.md). Changing a
`backend` block requires re-running `init`, and Terraform will offer to migrate the
existing state for you.

!!! note "This repo gitignores its lock files — deliberately, and it's the exception"
    Commit the lock file in anything real. This repository does the opposite: every
    `01-basics/` folder is a throwaway root whose whole purpose is to be re-resolved from
    scratch, and pinning them would hide the very behaviour the
    [provider versions lab](../basics/11-provider-versions.md) asks you to observe. A
    learning repo optimises for "what does `init` decide today"; a production repo
    optimises for "two machines behave identically". Those wants are opposite, and this is
    the one place in these docs where the repo is not a model to copy.

## Constraint vs. lock

Two different statements about versions, and confusing them is the source of most
"it worked yesterday" provider surprises.

| | Says | Written by |
|---|---|---|
| **Constraint** (`version = "~> 5.0"`) | what range is *acceptable* | you |
| **Lock file** | what was *actually chosen*, with checksums | `terraform init` |

## The operators

| Operator | Means |
|---|---|
| `= 2.4.1` | exactly this |
| `> 2.4.1` | anything newer — loose, and a good way to get surprised |
| `>= 2.4.1, < 3.0.0` | explicit range |
| `~> 2.4.1` | `>= 2.4.1, < 2.5.0` — patch updates only |
| `~> 2.4` | `>= 2.4, < 3.0` — minor updates allowed |

`~>` is the *pessimistic* constraint operator, and where the last digit sits changes its
meaning entirely. `~> 2.4.1` allows patches; `~> 2.4` allows minors. Getting that backwards
is how a provider major version arrives unannounced.

## Upgrading deliberately

```bash
terraform init            # respects the lock file; won't move versions
terraform init -upgrade   # re-resolves within the constraint, rewrites the lock file
git diff .terraform.lock.hcl
```

Plain `init` never upgrades a locked provider. `-upgrade` is the explicit opt-in, and the
resulting lock-file diff is the thing to review — it is the only record of what actually
changed underneath your config.

## Pinning Terraform itself

`required_providers` pins plugins. `required_version` pins the CLI:

```hcl
terraform {
  required_version = ">= 1.5.0"
}
```

Worth setting once a config uses anything version-gated (`moved` blocks, `import` blocks,
`optional()` in object types), because the failure mode otherwise is a syntax error on a
colleague's older CLI rather than a clear message.

## Key takeaway

Commit the lock file. The constraint expresses intent; the lock file is what makes two
machines and a CI runner produce byte-identical behaviour from the same config.

---

Labs: [Provider versions](../basics/11-provider-versions.md) ·
Quiz: [Providers & auth](../quiz/01-providers-and-auth.md) ·
Next: [Resources and state](04-resources-and-state.md)
