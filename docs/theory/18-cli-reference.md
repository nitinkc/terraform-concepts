# 18 — CLI reference

**Assumes:** everything before it. This page is lookup, not reading.

## The loop

| Command | Purpose |
|---|---|
| `terraform init` | download providers, configure the backend, create `.terraform/` + lock file |
| `terraform init -upgrade` | re-resolve provider versions within the constraints and rewrite the lock file |
| `terraform fmt -recursive` | canonical formatting |
| `terraform validate` | syntax and type checking, no API calls |
| `terraform plan` | refresh + diff config vs. state vs. real world; show proposed changes |
| `terraform plan -out=tf.plan` | save the plan so `apply` executes exactly what was reviewed |
| `terraform apply` | execute the plan against real infrastructure |
| `terraform apply tf.plan` | apply a saved plan — no re-diff, no prompt |
| `terraform destroy` | delete everything this config manages (does not touch `data` targets) |

## Narrowing a run

| Command | Purpose |
|---|---|
| `terraform plan -var="k=v"` | override one variable for this run (highest precedence) |
| `terraform plan -var-file="prod.tfvars"` | supply a variable file explicitly |
| `terraform plan -target=<addr>` | plan only one address and its dependencies — debugging only |
| `terraform plan -refresh=false` | skip the live refresh; trust state's cached values |
| `terraform apply -replace=<addr>` | force destroy + recreate of one resource |
| `terraform apply -auto-approve` | skip the confirmation prompt (CI only) |

`-target` is a diagnostic tool, not a workflow. A config that needs it routinely is a
config whose [root boundary is wrong](17-project-structure.md).

## State

| Command | Purpose |
|---|---|
| `terraform state list` | list all resource addresses currently tracked |
| `terraform state show <addr>` | show full recorded attributes of one resource |
| `terraform state mv <old> <new>` | rename an address without destroy/recreate |
| `terraform state rm <addr>` | forget a resource (real resource untouched, becomes unmanaged) |
| `terraform state pull` / `push` | download/upload raw state — last resort |
| `terraform import <addr> <cloud_id>` | map an existing real resource into state (state only, not code) |
| `terraform force-unlock <lock_id>` | release a stuck backend lock, after confirming nobody is applying |

## Outputs and inspection

| Command | Purpose |
|---|---|
| `terraform output` | show all outputs |
| `terraform output -raw <name>` | print a primitive output's bare value (shell-friendly) |
| `terraform output -json <name>` | print a structured output as JSON (pipe to `jq`) |
| `terraform show` | human-readable current state |
| `terraform show -json tf.plan` | machine-readable plan, for policy checks in CI |
| `terraform graph \| dot -Tsvg > graph.svg` | render the dependency graph |
| `terraform console` | REPL for evaluating expressions against current state |

`terraform console` is the fastest way to answer "what does this `for` expression actually
produce" without an apply.

## Workspaces

| Command | Purpose |
|---|---|
| `terraform workspace list` | list workspaces, `*` marks current |
| `terraform workspace new <name>` | create and switch |
| `terraform workspace select <name>` | switch |
| `terraform workspace show` | print current name — worth doing before any apply |

## Debugging

| Command | Purpose |
|---|---|
| `TF_LOG=DEBUG terraform plan` | full provider/API logging (`TRACE` for more, `INFO` for less) |
| `TF_LOG_PATH=tf.log TF_LOG=DEBUG terraform apply` | log to a file instead of the terminal |
| `terraform providers` | show which providers each module requires |
| `terraform version` | CLI and provider versions actually in use |

---

Next: [Glossary](19-glossary.md)
