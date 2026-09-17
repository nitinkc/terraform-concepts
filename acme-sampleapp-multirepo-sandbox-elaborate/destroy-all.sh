#!/usr/bin/env bash
# destroy-all.sh — tears down every tracked Acme resource in reverse dependency order.
# Run from any directory. Empty states are skipped, and every existing environment
# workspace is checked so a learning-session teardown does not leave billable resources.

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CLEAN_DESTROY_MARKER="$SCRIPT_DIR/.acme-clean-destroy"
CONSUL_OUTPUT_PREFIX="gitlab/terraform_outputs/v2/sample-org/"
BILLABLE_DESTROYED=0
FREE_DESTROYED=0
cd "$SCRIPT_DIR"

usage() {
  cat <<'EOF'
Usage: ./destroy-all.sh

Destroys all tracked Acme resources in reverse dependency order, clears the
local Consul output contracts, and records a clean teardown so the next plain
./restore-session.sh can recreate the learning environment.
EOF
}

case "${1:-}" in
  "") ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
esac

require_command() {
  local command_name=$1
  if ! command -v "$command_name" > /dev/null 2>&1; then
    echo "ERROR: $command_name is required." >&2
    exit 1
  fi
}

is_potentially_billable() {
  case "$1" in
    google_artifact_registry_repository|google_cloudfunctions2_function|google_compute_global_address|google_compute_router_nat|google_container_cluster|google_container_node_pool|google_dns_managed_zone|google_secret_manager_secret_version|google_sql_database_instance) return 0 ;;
    *) return 1 ;;
  esac
}

count_destroy_actions() {
  local plan_file=$1
  local resource_types=""
  local resource_type=""

  resource_types=$(terraform show -json "$plan_file" | jq -r '.resource_changes[]? | select(.change.actions == ["delete"]) | .type')
  while IFS= read -r resource_type; do
    [ -z "$resource_type" ] && continue
    if is_potentially_billable "$resource_type"; then
      BILLABLE_DESTROYED=$((BILLABLE_DESTROYED + 1))
    else
      FREE_DESTROYED=$((FREE_DESTROYED + 1))
    fi
  done <<< "$resource_types"
}

destroy_workspace() {
  local dir=$1
  local label=$2
  local workspace=$3
  local plan_file=""

  cd "$SCRIPT_DIR/$dir"
  terraform workspace select "$workspace" > /dev/null
  if [ -z "$(terraform state list 2>/dev/null)" ]; then
    echo "-- $label ($workspace): empty state, skipping"
    cd "$SCRIPT_DIR"
    return
  fi

  echo ""
  echo "=== Destroying $label ($dir, workspace: $workspace) ==="
  plan_file=$(mktemp "${TMPDIR:-/tmp}/acme-terraform-destroy.XXXXXX")
  terraform plan -destroy -input=false -out="$plan_file"
  count_destroy_actions "$plan_file"
  terraform apply -input=false -auto-approve "$plan_file"
  rm -f "$plan_file"
  cd "$SCRIPT_DIR"
}

destroy_root() {
  local dir=$1
  local label=$2
  local all_workspaces=${3:-false}
  local workspace=""
  local workspaces="default"

  if [ ! -d "$SCRIPT_DIR/$dir" ]; then
    echo "-- $label: directory not found, skipping"
    return
  fi

  cd "$SCRIPT_DIR/$dir"
  terraform init -input=false > /dev/null
  if [ "$all_workspaces" = true ]; then
    workspaces=$(terraform workspace list | awk '{sub(/^[* ]+/, ""); if ($0 != "") print}')
  fi
  cd "$SCRIPT_DIR"

  while IFS= read -r workspace; do
    [ -n "$workspace" ] && destroy_workspace "$dir" "$label" "$workspace"
  done <<< "$workspaces"
}

require_command terraform
require_command jq
require_command consul

cat <<'EOF'
This removes all Terraform-tracked Acme resources, including billable GKE,
Cloud SQL, DNS, reserved IP, Artifact Registry, and Cloud Functions resources
when present. Local Terraform state files are retained as empty state.
EOF
printf '%s' "Type destroy to continue: "
read -r confirmation
if [ "$confirmation" != "destroy" ]; then
  echo "Destroy cancelled."
  exit 1
fi

destroy_root "frontend/infra" "frontend" true
destroy_root "backend/infra" "backend" true
destroy_root "cloudsql/infra" "cloudsql" true
destroy_root "infrastructure/infra" "infrastructure"
destroy_root "sample-program/infra" "sample-program"

echo ""
echo "=== Clearing local Consul contracts ==="
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
if consul members > /dev/null 2>&1; then
  consul kv delete -recurse "$CONSUL_OUTPUT_PREFIX" > /dev/null || true
  echo "Cleared $CONSUL_OUTPUT_PREFIX"
else
  echo "WARNING: Consul is not reachable; stop its dev agent to discard stale in-memory contracts." >&2
fi

printf 'destroyed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$CLEAN_DESTROY_MARKER"

echo ""
echo "=== Destroy complete ==="
printf 'Potentially billable Terraform resources destroyed: %s\n' "$BILLABLE_DESTROYED"
printf 'No-direct-charge Terraform resources destroyed: %s\n' "$FREE_DESTROYED"
echo "These are Terraform resource counts, not a price estimate. Usage-based charges may take time to stop appearing."
echo "All tracked roots and workspaces were checked; empty states were skipped."
echo "The next plain ./restore-session.sh is authorized to rebuild this cleanly destroyed learning environment."
echo "Consul dev agent is still running locally and does not create a cloud bill."
