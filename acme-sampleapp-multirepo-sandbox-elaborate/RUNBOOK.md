# RUNBOOK — actually running this sandbox

Everything here is runnable against a real GCP project. It is **not**
runnable against your organization's real GKE cluster/Consul cluster — it
needs its own, which this runbook sets up (a lab-sized GKE cluster you create
and destroy yourself, and a local Consul dev agent standing in for a real
Consul cluster).

**Read the cost section before running `terraform apply` anywhere near the
GKE modules.** Everything else in this sandbox (VPC, DNS zone, Secret
Manager, Cloud SQL at the smallest tier) is cheap-to-free; GKE nodes are the
one thing here that meaningfully costs money per hour they're running.

---

## 0. One-time tool setup

```bash
# Auth — this sandbox uses your own gcloud credentials via Application
# Default Credentials, the same way `google_client_config.default` (used
# throughout for the kubernetes/helm provider tokens) expects.
gcloud auth application-default login
gcloud config set project <your-real-project-id>

# Local Consul dev agent — stands in for your org's real Consul cluster.
# `-dev` mode is in-memory, single-node, no ACLs, no persistence. Perfect for
# this and nothing else — never run -dev mode anywhere but your own machine.
consul agent -dev &
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500

# Verify:
consul kv put test/hello world
consul kv get test/hello   # should print "world"
```

If you don't have the `consul` CLI: `brew install consul` (macOS) or grab a
binary from releases.hashicorp.com/consul. No Docker required for `-dev`
mode.

---

## 1. Copy every tfvars example

```bash
for repo in sample-program infrastructure cloudsql backend frontend; do
  dir=$repo
  [ "$repo" != "sample-program" ] && [ -d "$repo/infra" ] && cp "$repo/infra/terraform.tfvars.example" "$repo/infra/terraform.tfvars"
done
cp sample-program/infra/terraform.tfvars.example sample-program/infra/terraform.tfvars
```

Then edit each `terraform.tfvars` — at minimum, `sample-program/infra/terraform.tfvars`
needs your real `project_id`.

---

## 2. Apply order (matches the dependency graph in README.md)

Each repo is `terraform init && terraform plan && terraform apply` from its
own `infra/` directory — they are genuinely independent state files, run
independently, exactly like the real 4-repo project.

```bash
cd sample-program/infra
terraform init
terraform plan     # safe — enable_gke_p/np default to false, nothing costs money yet
```

**Stop here and read the cost section below before going further.**

```bash
# When ready to actually stand up a cluster (recommended: np only, it's cheaper
# and it's what dev/qa/review environments use):
#   edit terraform.tfvars: enable_gke_np = true
terraform apply

cd ../../infrastructure/infra
terraform init && terraform apply

cd ../../cloudsql/infra
terraform init && terraform apply

cd ../../backend/infra
terraform init && terraform apply    # requires kubectl-style access — this repo's
                                       # kubernetes/helm providers authenticate using
                                       # the GKE cluster sample-program just published

cd ../../frontend/infra
terraform init && terraform apply
```

If any `apply` fails with something like "no host found" or a provider
config error, it almost always means the upstream repo hasn't been applied
yet, or `enable_gke_np`/`enable_gke_p` is still `false` — the dependency
graph in `README.md` is the actual troubleshooting order.

---

## 3. Tearing down

**Reverse order**, same as any dependency graph:

```bash
cd frontend/infra    && terraform destroy
cd ../../backend/infra      && terraform destroy
cd ../../cloudsql/infra     && terraform destroy
cd ../../infrastructure/infra && terraform destroy
cd ../../sample-program/infra && terraform destroy
```

Kill the Consul dev agent when done: `kill %1` (or find it with `jobs`).
`-dev` mode is in-memory anyway — nothing persists once it's killed.
```shell
kill $(pgrep consul)
```

---

## Cost warning — read before enabling GKE

`enable_gke_p` / `enable_gke_np` default to `false` specifically so you can
`plan` and read the whole graph without spending anything. Once you flip
either to `true`:

- You're paying for **1 running `e2-small` node** (spot pricing for `np`,
  on-demand for `p`) — order of cents/hour, but it accrues the whole time
  it's running, not just while you're actively using it.
- **Turn it off when you're done for the session.** `terraform destroy`
  from `sample-program/infra` removes the cluster and node pool. There's no
  "pause" — destroy and re-apply next session is the normal workflow for a
  lab cluster.
- Consider enabling **only `enable_gke_np`** rather than both — one cluster
  is enough to exercise the entire dependency graph end to end (`backend`
  and `frontend` both read `local.program_gcp` keyed by `p_or_np`, and any
  non-`default` Terraform workspace resolves to `np`).
- Check current GKE/Compute Engine pricing for your region before leaving
  anything running unattended — prices change and this file won't stay
  current.
