# 17 — Project structure and file conventions

**Assumes:** [Modules](12-modules.md).

## There is no entry point

Unlike most programming languages, Terraform has no `main()`. Running `plan`/`apply` in a
directory causes Terraform to read and merge **every** `.tf` file present into one logical
configuration. File names and file order do not determine execution order. You could put
everything in one file and it would behave identically.

**Ordering comes from the [reference graph](06-dependencies-and-the-graph.md).** If a
subnet in `subnet.tf` references a VPC in `vpc.tf`, Terraform creates the VPC first —
regardless of which file was parsed first, and regardless of alphabetical order.

So every convention below is for humans. Terraform is indifferent.

## Conventional file names

| File | Typical purpose |
|:---|:---|
| `providers.tf` | provider declarations and configuration (project, region, credentials) |
| `versions.tf` | `required_version` and `required_providers` — sometimes merged into `providers.tf` |
| `variables.tf` | input variable declarations — the "input schema" |
| `locals.tf` | derived values, once there are more than a couple |
| `main.tf` | primary resources and module calls — the human-oriented entry point |
| `data.tf` | data sources, when there are enough to be worth isolating |
| `outputs.tf` | output declarations — the "output schema" |
| `backend.tf` | the `backend` block |
| `terraform.tfvars` | actual values (gitignored if it holds anything environment-specific) |
| `<domain>.tf` | `iam.tf`, `gcs.tf`, `vpc.tf` — split by resource domain once `main.tf` is unwieldy |

The rule of thumb: **the schema files (`variables.tf`, `outputs.tf`, `versions.tf`) always
exist; everything else splits by domain when it gets long.** A reader looking for "what can
I configure" and "what does this expose" should never have to grep.

## A root is a blast radius

The more important structural decision is where to draw the *root* boundary, because one
root = one state file = one apply = one failure domain.

| Signal that a root should be split | Why |
|---|---|
| `apply` takes long enough that people avoid running it | slow feedback breeds drift |
| Two teams change different halves of it | contention and review noise |
| One half is stateful (databases) and the other is churny (apps) | you don't want app deploys planning against a DB |
| Different environments need different provider config | workspaces can't express it ([§13](13-state-lifecycle.md)) |

Splitting introduces the coordination cost described in
[Cross-config composition](15-cross-config-composition.md), so it is a trade, not an
upgrade.

## Directory layout that scales

```
repo/
├── modules/                 child modules — reusable, never applied directly
│   └── service_account/
├── envs/
│   ├── dev/                 a root: backend.tf + terraform.tfvars + module calls
│   └── prod/                a root: same modules, different values and backend
```

The `envs/<name>/` directory-per-environment pattern is verbose but explicit: the backend
prefix, the tfvars, and the provider config are all visible in the directory you're
standing in. That's why it's the common production choice over
[workspaces](13-state-lifecycle.md) — you can't apply to prod by forgetting which invisible
workspace you selected.

## Housekeeping

- `.terraform/`, `terraform.tfstate*`, `*.tfvars` holding secrets, and `crash.log` are
  gitignored. `.terraform.lock.hcl` is committed
  ([§3](03-init-and-version-constraints.md)).
- This repo deviates on both, on purpose: lock files are gitignored so the labs re-resolve
  ([§3](03-init-and-version-constraints.md#what-init-creates)), and `terraform.tfvars` is
  *committed* because every value in it is a lab placeholder or a non-sensitive project
  ID — a reader who has to reconstruct tfvars before anything runs never runs anything.
  The moment a real secret needs to reach a config, it goes through `TF_VAR_` or a secret
  manager, not into a file. Copy the rule above, not this repo's exception.
- `terraform fmt -recursive` and `terraform validate` are cheap and belong in CI.
- One directory per concept is fine for *learning* repos — this one does exactly that in
  [`01-basics/`](../basics/index.md) — and is wrong for production, where the boundary
  should follow the blast radius, not the syllabus.

## Key takeaway

Filenames are documentation. Directory boundaries are architecture: they decide what gets
destroyed together, applied together, and reviewed together.

---

Labs: [Core GCP root](../gcp/01-core-root.md),
[Stage 2 conventions](../basics/index.md#conventions) ·
Next: [CLI reference](18-cli-reference.md)
