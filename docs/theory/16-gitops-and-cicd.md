# 16 — GitOps and the CI/CD execution model

**Assumes:** [Backends and state security](14-backends-and-state-security.md).

## The problem this solves

If developers run Terraform locally, their laptops need direct read access to the state
file — which contains secrets. There is no IAM trick that grants "run plan" without
granting "read state" ([§14](14-backends-and-state-security.md)). Every engineer who can
plan is, in effect, holding production secrets.

## The fix: move execution off laptops

1. The developer writes HCL locally but has **no** credentials to run `plan`/`apply`
   against production state.
2. The developer opens a pull request.
3. A CI/CD runner (GitHub Actions, GitLab CI, …), using a dedicated **non-human service
   account** with the necessary state/GCP permissions, executes `terraform plan` in an
   isolated environment.
4. The plan output is posted back to the PR for human review — but the human never touched
   the state file or held its credentials.
5. Merging the PR triggers `apply` with a second, higher-privilege identity.

The audit trail is the Git history, which is the actual point of calling it GitOps: every
infrastructure change has an author, a reviewer, and a diff.

## The new attack surface: arbitrary code execution via PR

Because the runner executes whatever HCL is on the PR branch, a malicious contributor can
smuggle in a `null_resource` with a `local-exec` provisioner that runs arbitrary shell
commands **on the trusted runner** — for example, exfiltrating the state file to an
external server with `curl`.

This isn't hypothetical or exotic; it's the direct consequence of "the runner runs your
code with production credentials." Provisioners
([Stage 2](../basics/13-provisioners-and-archive.md)) make it a one-liner, but an
`external` data source or a malicious module `source` does the same job.

## Defence in depth

| Guardrail | Stops | Doesn't stop |
|---|---|---|
| **PR approval gates** — no pipeline run on unreviewed branches | the whole class of attack | an approved-but-unread malicious diff |
| **Read-only plan-stage service account** | writes and deletions during `plan` | reading/exfiltrating state |
| **Network isolation** — private runners, restricted egress | `curl`-to-attacker-server | exfiltration via build logs |
| **Secret masking** | accidental secret prints | deliberate obfuscation |

**Residual risk — build log exfiltration.** With egress blocked, a malicious PR can simply
`cat` the state file or `echo` a secret env var to stdout. CI systems capture stdout into
build logs, which are often visible to everyone with repo access.

**Mitigation and its limit.** CI platforms register known secret values and scan stdout in
real time, replacing literal matches with `***`/`[MASKED]`. Masking is **literal string
matching**, so it is trivially bypassed by transforming the secret before printing:

```bash
echo $DB_PASSWORD | base64      # nothing to match, nothing masked
```

Masking is therefore a safety net for *accidental* leaks, not a defence against a
*malicious* actor. **PR approval gates remain the primary control** — everything else is
damage limitation.

## Key takeaway

Moving Terraform into CI removes secrets from laptops and replaces them with a single
trusted executor that runs untrusted code. That's a better trade, but only if the approval
gate is real; without it you've centralised the credentials without protecting them.

---

Code: `.github/workflows/publish-docs.yml` (this site's own pipeline) ·
Next: [Project structure](17-project-structure.md)
