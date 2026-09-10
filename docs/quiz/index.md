# Quiz

Thirty-six questions, split by topic so you can revise one area at a time instead of
scrolling one long page. Each page scores independently.

Every question here came out of something that actually happened — a live experiment, a
failed apply, or a wrong answer that got corrected. None of them are paraphrased from
documentation, which is why several have a "this happened for real" note in the
explanation.

| Topic | Questions | Covers |
|---|---:|---|
| [Providers, Auth & Initialization](01-providers-and-auth.md) | 5 | ADC, `required_providers` vs `provider`, provider defaults as fallback, `init` |
| [Resources, Data Sources, State & Drift](02-resources-state-and-drift.md) | 5 | `data` vs `resource`, non-atomic apply, import vs recreate |
| [Variables, Expressions & Guards](03-variables-expressions-and-guards.md) | 6 | precedence, `count = 0`, `for_each` over modules, guard propagation |
| [Multi-Repo & Consul Contracts](04-multirepo-and-consul.md) | 6 | Consul KV vs `terraform_remote_state`, publish order, grant ownership |
| [GKE, Kubernetes & Workload Identity](05-gke-and-workload-identity.md) | 10 | node service accounts, WI annotation linkage, capacity vs allocatable |
| [Debugging & Verification Methodology](06-debugging-and-verification.md) | 4 | hypothesis ordering, independent verification |

## Where each question came from

Every question carries a non-rendering `<!-- source: session-NN -->` comment in the
markdown, so provenance survives future reshuffling. Questions tagged `unfiled` are ones
whose originating session isn't recorded in the [session notes](../sessions/index.md) —
mostly the GKE node-sizing and `kubectl` Forbidden series, which came from work done after
Session 3 was written up. Correct the tags as you reconstruct them.

## Adding questions after a session

1. Pick the topic page the question belongs to. If a question is genuinely about two
   topics, file it where the *incident* happened, not where the concept lives — you'll
   remember it that way.
2. Add `<!-- source: session-NN -->` on the line above the `<quiz>` block.
3. Bump the count in the table above and in the `**N questions.**` line on the topic page.
4. If a question introduces a concept not yet in the
   [concept index](../theory/concept-index.md), add a row there too. That is the one step that
   keeps the material navigable as it grows.

Create a new topic page only when an existing one passes roughly ten questions — six pages
of five to eight is the point of this split, and more pages than topics defeats it.
