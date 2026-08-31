#!/usr/bin/env bash
# restore-session2.sh — brings the sandbox back up to exactly where Session 2
# paused: sample-program applied (np cluster only — p was never created),
# infrastructure applied on top of it, backend switched to the "dev"
# workspace but NOT yet applied (that's Session 3's actual starting point).
#
# Prerequisites this script assumes are already true:
#   - gcloud auth application-default login has been run at least once
#     (refresh token doesn't expire on its own — see Session 1 notes)
#   - sample-program/infra/modules/gke/main.tf already has the dedicated
#     node-SA fix (from Session 2) — this script does NOT re-apply that code
#     change, it assumes your local files already have it
#   - infrastructure/infra/{main,secrets,outputs}.tf already have the
#     guard-propagation patch from Session 2
#   - terraform.tfvars exists in sample-program/infra and infrastructure/infra
#     (copied from .example and filled in, per Session 1/2)
#
# Run from the repo root.

set -euo pipefail

echo "=== 1. Starting local Consul dev agent ==="
if pgrep -f "consul agent -dev" > /dev/null; then
  echo "Already running."
else
  consul agent -dev > /tmp/consul-dev.log 2>&1 &
  sleep 2
  echo "Started (log: /tmp/consul-dev.log)."
fi
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500

echo ""
echo "=== 2. Checking gcloud auth ==="
if ! gcloud auth application-default print-access-token > /dev/null 2>&1; then
  echo "No valid Application Default Credentials found — running login."
  gcloud auth application-default login
else
  echo "ADC already valid."
fi

echo ""
echo "=== 3. Applying sample-program (VPC, np GKE cluster, DNS) ==="
echo "Reminder: this is the billable step. Confirm terraform.tfvars has"
echo "enable_gke_np = true and enable_gke_p = false before continuing."
read -p "Press enter to continue, or Ctrl+C to abort and check tfvars first..."
(cd sample-program/infra && terraform init -input=false && terraform apply)

echo ""
echo "=== 4. Applying infrastructure (SSO secrets, published to Consul) ==="
(cd infrastructure/infra && terraform init -input=false && terraform apply)

echo ""
echo "=== 5. Selecting the 'dev' workspace in backend (no apply yet) ==="
(cd backend/infra && \
  terraform init -input=false && \
  (terraform workspace select dev 2>/dev/null || terraform workspace new dev))

echo ""
echo "=== Done — restored to end-of-Session-2 state. ==="
echo "backend/infra is on the 'dev' workspace but not yet applied — that's"
echo "the actual Session 3 starting point (verify 'terraform plan' resolves"
echo "cleanly now that infrastructure/infra has been re-applied)."
