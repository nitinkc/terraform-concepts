# 1 — What Terraform is

**Assumes:** nothing.

Terraform is a program that reads your description of infrastructure, compares it against
what exists, and makes the smallest set of API calls that closes the gap. Everything else
in this section is a consequence of that one sentence.

## Declarative, not imperative

`gcloud compute instances create ...` is **imperative** — you name the steps, and running
it twice creates two things or fails. A `.tf` file is **declarative** — you name the end
state, and running it twice is a no-op, because the second run finds nothing to change.

|  | Imperative (`gcloud`, `kubectl create`) | Declarative (Terraform) |
|---|---|---|
| You write | the steps | the desired end state |
| Run twice | happens twice | second run is a no-op |
| Needs to know | nothing about current state | everything about current state |

That last row is the price of being declarative, and it's why [state](04-resources-and-state.md)
exists at all. A declarative tool cannot compute a diff without knowing the current value.

## The three-way comparison

Every `plan` compares **three** things, not two:

| Source | What it is |
|---|---|
| Your HCL | the desired state |
| The state file | what Terraform believes it created last time |
| The live API | what is actually there right now |

**HCL always wins.** A plan proposes changes to the real world to bring it in line with the
code — never the reverse. Someone editing a resource by hand in the console does not change
your config; it creates [drift](13-state-lifecycle.md) that the next apply reverts.

## Core vs. provider

Terraform ships as two separable halves, and knowing which half you're arguing with saves
real debugging time:

| Half | Knows about | Responsible for |
|---|---|---|
| **Terraform core** (the `terraform` binary) | HCL syntax, the dependency graph, state, the plan/apply loop | *ordering and diffing* |
| **A provider plugin** (e.g. `hashicorp/google`) | that GCP service accounts exist, which fields they have, which fields can be updated in place | *the actual API calls* |

Core has never heard of GCP. It cannot tell you that `account_id` can't be changed in
place — that constraint lives in the provider, because it reflects a real limitation of the
Google API. See [Providers and authentication](02-providers-and-authentication.md).

## HCL

HashiCorp Configuration Language is the `.tf` file syntax: typed blocks, arguments, and
expressions. It is not a scripting language — there are no statements, no loops in the
procedural sense, and no execution order you control. There are only declarations and the
references between them.

```hcl
block_type "label_one" "label_two" {
  argument = expression
}
```

Every block you will meet is one of a small set: `terraform`, `provider`, `resource`,
`data`, `variable`, `locals`, `output`, `module`, and `moved`/`import`. This section covers
them in the order they become useful.

## The loop

Four commands, one cycle. Everything else is a variation on these.

| Command | What it does |
|---|---|
| `init` | downloads providers, sets up the backend — see [§3](03-init-and-version-constraints.md) |
| `plan` | refreshes state from the live API, diffs, prints the proposed changes |
| `apply` | executes a plan |
| `destroy` | plans and executes the removal of everything this config owns |

`plan` is free and read-only. It is the command you should run reflexively, and the one
that answers most questions about how Terraform behaves — including a fair number of the
questions in this section.

## Key takeaway

Terraform's whole job is diffing three sources of truth and reconciling them toward your
code. Any surprising behaviour is nearly always one of: state doesn't say what you think it
says, the provider disagrees with what you think the API allows, or the graph ordered
things differently than you assumed.

---

Next: [Providers and authentication](02-providers-and-authentication.md)
