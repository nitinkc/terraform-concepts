# 13 — Secrets Delivery & Vault (dev-mode lab)

Companion to reference 12: where 12 secures the *pipeline*, this secures the
*secret lifecycle* — and gives you a real Vault to practice on, the same
way `RUNBOOK.md` uses a Consul `-dev` agent as a stand-in.

---

## 1. The decision matrix

| Store | Strength | Weakness | Pick when |
|-------|----------|----------|-----------|
| **GCP Secret Manager** | managed, IAM-native, versioned | GCP-only | you're on GCP (this repo's `infrastructure/infra/secrets.tf` already uses it) |
| **HashiCorp Vault** | dynamic secrets (DB creds minted per-request with TTL), multi-cloud, rich auth methods | you run it; real HA is a project | you need dynamic creds or multi-cloud |
| **Consul KV** | you're already running it | not a secret store (no encryption at rest by default, no ACLs in `-dev`) | this repo: the *contracts* use-case it already serves |
| **k8s Secret only** | zero infra | no audit/versioning/rotation | minikube labs only |

The multirepo already uses two of these correctly: SM for the SSO secret
(storage), Consul for cross-root JSON contracts (wiring, not secrets).

## 2. Vault dev lab — mirrors the Consul pattern

```bash
brew install vault
vault server -dev &            # in-memory, unsealed, root token printed
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=<printed root token>
```

```bash
# kv v2 — the 80% case
vault secrets enable -path=kv kv-v2
vault kv put kv/acme/backend sso_client_id=abc sso_client_secret=xyz
vault kv get kv/acme/backend

# the concept that makes Vault different — DYNAMIC secrets:
# a real vault can mint a Cloud SQL / Postgres credential ON DEMAND with a
# TTL, so the "rotation" problem disappears: creds die on their own.
# (needs a configured db engine — concept only in dev mode)

vault kv metadata get kv/acme/backend   # versioning: old values preserved
vault kv rollback -version=1 kv/acme/backend
```

Dev-mode rules identical to the Consul `-dev` agent: **unauthenticated
in-memory playpen — never outside your machine.**

## 3. The delivery half — where ESO fits

Storage is solved by SM/Vault; *delivery* is the ESO `ExternalSecret` —
see `KubernetesConcepts` lab 12 for the full hands-on and lab 13 for the
sops alternative. For the acme backend, the wiring already exists end to
end:

```
infrastructure/infra/secrets.tf          creates  acme-sampleapp-sso-config-<env>
backend/infra/iam.tf                     grants   backend GSA → secretAccessor
backend chart (externalSecrets.enabled)  delivers ExternalSecret → Secret sso-config
deployment env wiring                    consumes SSO_CLIENT_ID / SSO_CLIENT_SECRET
```

Enable it in the backend chart:

```yaml
# values-dev.yaml
externalSecrets:
  enabled: true
  remoteKey: acme-sampleapp-sso-config-dev   # SM secret_id
  clusterSecretStore: gcp-sm                  # pre-created SecretStore (WI)
```

The chart ships the `ExternalSecret`/`SecretStore` templates
(`templates/external-secrets.yaml`) — guarded, off by default, so the chart
still applies where no store exists (minikube without ESO).

## 4. Interview-grade distinction

> "Consul KV vs Vault?" — KV is a *config store* you're abusing as a secret
> store; Vault mints, encrypts, TTLs, and audits secrets as a first-class
> object. In this repo Consul carries contracts (non-secret wiring); SM
> carries secrets; Vault is the multi-cloud/dynamic-creds answer.

## 5. Deliberate break

- `vault kv get` with a wrong `VAULT_TOKEN` → permission denied: Vault's
  auth model is tokens/policies, not network trust.
- Kill the `-dev` server → data gone (in-memory). Same lesson as Consul
  `-dev`: dev mode proves the workflow, not the durability.
- Set `externalSecrets.enabled: true` with no ESO installed →
  `no matches for kind ExternalSecret` (the CRD-before-CR signature from
  lab-09). Delivery needs the controller first.

## See also

- [12 — Security Scanning, Policy & TF in CI](12-security-policy-and-pipelines.md)
- `KubernetesConcepts` lab 12 (ESO) / lab 13 (sops+age)
- `DevOpsLearning` theory 13 (three-layer taxonomy)
