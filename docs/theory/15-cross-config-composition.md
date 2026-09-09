# 15 — Cross-config composition

**Assumes:** [Data sources](11-data-sources.md) and
[Backends and state security](14-backends-and-state-security.md).

One state file per config is a boundary, and once there is more than one config the
question becomes: how does repo B learn a value that repo A created?

## Why split at all

Splitting resource ownership across configs — repo A owns the database as a `resource`,
repo B reads its connection details via a `data` block — buys three things:

| Benefit | Why |
|---|---|
| Least privilege | consumers don't need write/manage permissions on what they read |
| Blast radius | a broken apply in one repo can't destroy another repo's resources |
| Independent cadence | teams apply on their own schedule, not in one lockstep root |

And costs one: **ordering.** Repo A must apply before repo B can plan, and nothing in
Terraform enforces that for you.

## Two ways to read across the boundary

**1 — a shared KV store (e.g. Consul)**

Repo A publishes non-sensitive values (IP, port, connection name) to Consul; repo B reads
them with `data "consul_keys"`. Repo B never touches repo A's state file, so sensitive
values that live only in repo A's state (a DB password) are never exposed to repo B.

**2 — `terraform_remote_state`**

Repo B reads repo A's state file directly from its backend:

```hcl
data "terraform_remote_state" "infra" {
  backend = "gcs"
  config = {
    bucket = "my-tf-state"
    prefix = "infrastructure/"
  }
}

# only outputs are reachable
locals {
  vpc_id = data.terraform_remote_state.infra.outputs.vpc_id
}
```

Simpler — no extra infrastructure — but it couples repo B to repo A's **entire** state
file. Reading it requires read access to the whole thing, including anything sensitive
stored there, and per [§14](14-backends-and-state-security.md) that access can't be
narrowed to just the outputs.

| | Shared KV (Consul) | `terraform_remote_state` |
|---|---|---|
| Security isolation | good — publisher chooses what's shared | weak — full state read access |
| Operational cost | a system to run and keep up | none |
| Coupling | to a contract (key names) | to another config's state layout |
| Failure mode | KV down → plan fails | bucket unreachable → plan fails |

**Trade-off in one line:** Consul-style gives you isolation at the cost of an extra
dependency; `terraform_remote_state` gives you simplicity at the cost of isolation.

## The contract is the thing to design

Whichever mechanism you pick, what actually matters is the **contract**: which keys or
outputs exist, what they're named, and what they mean. Two rules that keep it maintainable:

- **Publish deliberately, not incidentally.** An output is an API
  ([§10](10-outputs.md)); renaming one breaks a consumer you may not know about.
- **Never publish a secret across the boundary.** Publish the *reference* — a Secret
  Manager resource name — and let the consumer read the value with its own permissions.

## Failure modes, in the order you'll hit them

1. **Consumer applied before publisher.** The key doesn't exist yet; the plan fails with a
   not-found. Correct behaviour, but the error names the key, not the missing apply.
2. **Publisher renamed a key.** Same error, harder to diagnose, and it happens after a
   change to a repo the consumer's owner never saw.
3. **Publisher destroyed.** Every consumer's plan now fails, including plans that had
   nothing to do with the shared value — see
   [refresh-time dependency](11-data-sources.md).
4. **Stale value read.** Consul holds what was last published; if the publisher's apply
   half-failed, the consumer happily reads an obsolete IP. This is the quiet one.

Because of (4), the only reliable check is
[independent verification](../quiz/06-debugging-and-verification.md) — query the real
resource, don't trust that a successful apply means the contract is correct.

## Key takeaway

Multi-repo Terraform trades a coordination problem for a permissions problem, and the
coordination problem is unavoidable. Choose the mechanism based on whether the publisher's
state holds secrets: if it does, don't hand out read access to it.

---

Labs: [Lab 18](../gcp/02-lab-notes.md#lab-18-capstone-apply-to-real-acme-sampleapp-repo),
[the sandbox](../sandbox/index.md) ·
Quiz: [Multi-repo & Consul](../quiz/04-multirepo-and-consul.md) ·
Next: [GitOps and CI/CD](16-gitops-and-cicd.md)
