# Stage 3 — GCP

The same concepts as [Stage 2](../basics/index.md), against a real cloud API — where
resources have quotas, org policies, propagation delays, and a bill.

This stage has two halves, and they cover different code:

| Page | Code it documents | What it is |
|---|---|---|
| [Core GCP root](01-core-root.md) | [`02-gcp-terraform/01-core-gcp-resources/`](https://github.com/nitinkc/terraform-concepts/tree/main/02-gcp-terraform/01-core-gcp-resources) | One Terraform root split across files by concern. Providers, a GCS backend, data sources, locals, a VPC, a module, `for_each`, `dynamic` blocks, IAM and buckets. Start here. |
| [Lab notes 1–18](02-lab-notes.md) | the `acme-sampleapp` sandbox | Chronological notes from running each concept against a real project — what was typed, what was verified in the console, what broke. |

Read the walkthrough first: it's the runnable code in this repository, laid out the way a
real root is laid out. Then work the lab notes, which go deeper on individual mechanics
(workspaces, provider aliasing, import and drift) and record what actually happened rather
than what was supposed to.

## Prerequisites

```bash
gcloud auth application-default login    # writes an OAuth refresh token to
                                         # ~/.config/gcloud/application_default_credentials.json
gcloud config set project YOUR_PROJECT_ID
```

The `google` provider picks that file up automatically. **No credentials go in the HCL** —
see [Theory §2](../theory/02-providers-and-authentication.md).

## Create the state bucket first

The backend bucket must exist *before* `terraform init`, and Terraform cannot create its
own backend:

```bash
gsutil mb -l us-central1 gs://YOUR-UNIQUE-BUCKET-NAME-tfstate
```

This is a genuine chicken-and-egg, not an oversight. `init` connects to the backend before
any resource is evaluated, so a config cannot bootstrap the bucket it stores its own state
in. Real repos solve it with a separate one-off bootstrap config, or by creating the bucket
by hand once and never touching it again.

Bucket names are globally unique across all of GCP, so `terraform-learning-tfstate` is
probably already taken by someone. Pick your own.

## Cost

Small but not zero.

| Resource | Cost |
|---|---|
| `e2-medium` VM | The only meaningful line item — bills per second while it exists |
| Buckets, service accounts, IAM bindings, VPC | Effectively free at this scale |

`terraform destroy` when you stop for the day. The VM is the thing that will quietly cost
you money over a weekend.

## Then

Once both pages make sense, [Stage 4](../sandbox/index.md) is five interdependent roots
with a Consul contract, GKE, Cloud SQL and Helm — where no root can be understood in
isolation, and the bill is real.
