# acme-sampleapp — Terraform + Helm learning sandbox

Sanitized personal practice copy — same architecture and Terraform mechanics as a
real production repo, with all organization-specific naming genericized:

- Internal Consul/GitLab paths → generic `sample-org` placeholders

Nothing here will actually run — `data.consul_keys.remote_outputs` points at
Consul paths that don't exist, and there's no real GCP project wired up. That's
expected: this is for reading, tracing dependency graphs, and rewriting pieces
by hand — not for `terraform apply`.

## Layout

```
terraform/          — root Terraform module
  versions.tf        provider + backend requirements
  providers.tf        kubernetes/helm provider config, sourced from Consul-read GKE creds
  variables.tf        input variables (image repo/tag, static_env flag, ops AD group)
  main.tf              Consul data source, locals, namespace, GSA, the helm_release
  cloudsql.tf          locals that decode the cloudsql repo's Consul-published outputs
  iam.tf               cross-project IAM bindings + the shell_script grant/revoke bridge
  rbac.tf              in-namespace Role/RoleBinding for the ops team
  outputs.tf           values exposed for other repos/consumers to read

charts/acme-sampleapp-backend/   — the Helm chart the helm_release resource installs
  Chart.yaml
  values.yaml, values-dev.yaml, values-qa.yaml, values-prod.yaml
  templates/
    _helpers.tpl        name/label helpers + the DATABASE_URL template
    deployment.yaml
    service.yaml
    serviceaccount.yaml
```

## Why it's split into two Terraform-adjacent layers

- **Terraform** owns anything cloud/cluster-level: the namespace itself, the GCP
  service account, Workload Identity binding, cross-project IAM roles, and the
  Cloud SQL database user + in-database grants (via the `shell_script` bridge).
- **Helm** (invoked *by* Terraform via `helm_release`) owns anything
  Kubernetes-object-level: the Deployment, Service, ServiceAccount, and the
  Cloud SQL Auth Proxy sidecar.

Terraform composes the values it passes into Helm from three sources, layered
in this order inside `main.tf`'s `helm_release` block:
1. A static `values-<env>.yaml` file (env-specific resource sizing).
2. A `yamlencode({...})` block of values computed at plan time — this is where
   `local.cloudsql_enabled`, the GSA email, and image repo/tag get injected.

## What to trace first

1. Read `main.tf` locals top to bottom — most of the repo's "logic" lives there.
2. Then `cloudsql.tf` — see how a separate repo's state becomes local values here
   with zero direct Terraform state coupling (all via Consul JSON).
3. Then the `depends_on` block at the bottom of `main.tf` and the comment above
   it — that's the single most instructive line in the whole repo.
