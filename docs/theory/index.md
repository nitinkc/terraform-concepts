# Stage 1 — Theory

Definitions and mechanics, ordered so that each page only needs the ones before it. No
cloud account, no credentials, no cost — this is the stage you can read on a train.

Nineteen pages, each one topic. Read them in order the first time; after that, come in
through the [concept index](concept-index.md) or the [glossary](19-glossary.md).

## The sequence

| # | Page | The question it answers |
|---|---|---|
| 1 | [What Terraform is](01-what-terraform-is.md) | What does declarative actually mean, and what gets compared to what? |
| 2 | [Providers and authentication](02-providers-and-authentication.md) | Who makes the API calls, and as whom? |
| 3 | [`terraform init` and version constraints](03-init-and-version-constraints.md) | What does `init` do, and why commit the lock file? |
| 4 | [Resources and state](04-resources-and-state.md) | What does Terraform own, and how does it remember? |
| 5 | [Resource identity and change behaviour](05-resource-identity-and-change.md) | Why did renaming it destroy it, and why is *that* field force-new? |
| 6 | [Dependencies and the graph](06-dependencies-and-the-graph.md) | What decides the order things are created in? |
| 7 | [Variables and locals](07-variables-and-locals.md) | Where do values come from, and which source wins? |
| 8 | [Expressions and conditionals](08-expressions-and-conditionals.md) | How do you express "only if", with no `if` statement? |
| 9 | [`count`, `for_each` and `dynamic`](09-count-for-each-and-dynamic.md) | How do you make many of something without churning all of it? |
| 10 | [Outputs](10-outputs.md) | How does a value get out of a config? |
| 11 | [Data sources](11-data-sources.md) | How do you read something you don't own? |
| 12 | [Modules](12-modules.md) | How do you package infrastructure for reuse, and when shouldn't you? |
| 13 | [State lifecycle](13-state-lifecycle.md) | What happens when state and reality disagree? |
| 14 | [Backends and state security](14-backends-and-state-security.md) | Where should state live, and who can read the secrets in it? |
| 15 | [Cross-config composition](15-cross-config-composition.md) | How do two repos share a value, and what breaks? |
| 16 | [GitOps and CI/CD](16-gitops-and-cicd.md) | Why shouldn't developers run `apply` at all? |
| 17 | [Project structure](17-project-structure.md) | Which file, which directory, which root? |
| 18 | [CLI reference](18-cli-reference.md) | Which command was it again? |
| 19 | [Glossary](19-glossary.md) | What does that word mean? |

## How this connects to the rest

| Stage | Relationship to this one |
|---|---|
| [Stage 2 — Basics](../basics/index.md) | the same mechanics, run locally against `local`/`random`/`null` — every page here links to its lab |
| [Stage 3 — GCP](../gcp/index.md) | the same mechanics against a real project, in 18 labs |
| [Stage 4 — Sandbox](../sandbox/index.md) | all of it at once, plus the failure modes that only appear at scale |
| [Quiz](../quiz/index.md) | 33 questions, all drawn from things that actually broke |

Pages 1–12 are the mechanics you need to write Terraform. Pages 13–17 are the ones you need
to run it somewhere that matters — they're the second half for a reason, but they're also
where the expensive mistakes live.

## Reading it as reference

- Every page opens with an **Assumes** line naming its one prerequisite.
- Every page closes with links to the labs that run the concept for real and the quiz that
  tests it.
- Section numbers (`§4`, `§13`) used elsewhere in these docs refer to the numbers in the
  table above.

Start with **[What Terraform is](01-what-terraform-is.md)**.
