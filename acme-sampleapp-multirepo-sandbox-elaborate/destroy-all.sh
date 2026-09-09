#!/usr/bin/env bash
# destroy-all.sh — tears down every applied repo in reverse dependency order.
# Run from the repo root (the directory containing backend/, frontend/, etc.)
#
# As of the end of Session 2: only sample-program and infrastructure have
# real applied resources. backend/frontend/cloudsql destroys below are
# included for completeness/safety (harmless no-ops on empty state) — skip
# them with -s if you want to save a few seconds.

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

SKIP_EMPTY=false
[ "${1:-}" = "-s" ] && SKIP_EMPTY=true

destroy_repo() {
  local dir=$1
  local label=$2
  local workspace=${3:-default}
  if [ ! -d "$dir" ]; then
    echo "-- $label: directory not found, skipping"
    return
  fi
  echo ""
  echo "=== Destroying $label ($dir, workspace: $workspace) ==="
  (
    cd "$dir"
    terraform init -input=false > /dev/null
    terraform workspace select "$workspace" > /dev/null
    terraform destroy -input=false -auto-approve
  )
}

if [ "$SKIP_EMPTY" = false ]; then
  destroy_repo "frontend/infra"      "frontend"
  destroy_repo "backend/infra"       "backend" "dev"
  destroy_repo "cloudsql/infra"      "cloudsql"
fi

destroy_repo "infrastructure/infra" "infrastructure"
destroy_repo "sample-program/infra" "sample-program (GKE clusters — this is the billable one)"

echo ""
echo "=== Done. ==="
echo "Consul dev agent is still running (in-memory, no persistence needed)."
echo "Stop it if you want: kill \$(pgrep -f 'consul agent -dev')"
