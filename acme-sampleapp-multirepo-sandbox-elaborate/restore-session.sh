#!/usr/bin/env bash
# restore-session.sh — safely resume the Acme learning sandbox.
# Run from any directory. Existing local Terraform state is reused by default;
# use --bootstrap only when an intentional first-time apply is required.

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

BOOTSTRAP=false
REFRESH_CONSUL=false
REPAIR_FAILED_HELM=false
SKIP_BACKEND=false
CLEAN_DESTROY_MARKER="$SCRIPT_DIR/.acme-clean-destroy"
BILLABLE_ADDED=0
FREE_ADDED=0

usage() {
  cat <<'EOF'
Usage: ./restore-session.sh [options]

Options:
  --bootstrap       Allow creation when a repo has no local Terraform state.
                    Use this only for the first setup of the sandbox.
  --refresh-consul  Clear the local Consul KV namespace before applying and
                    republish tracked Consul outputs from Terraform state.
  --repair-failed-helm
                    Uninstall an orphaned Helm release whose status is failed
                    but which is absent from Terraform state.
  --skip-backend    Apply sample-program and infrastructure only.
  -h, --help        Show this help.

The default mode resumes existing resources or rebuilds resources after a
successful ./destroy-all.sh. Missing or unexpectedly empty state still fails
closed; use --bootstrap only for an intentional first setup.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bootstrap) BOOTSTRAP=true ;;
    --refresh-consul) REFRESH_CONSUL=true ;;
    --repair-failed-helm) REPAIR_FAILED_HELM=true ;;
    --skip-backend) SKIP_BACKEND=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

require_command() {
  command_name=$1
  install_hint=${2:-}
  if ! command -v "$command_name" > /dev/null 2>&1; then
    echo "ERROR: $command_name is required.${install_hint:+ $install_hint}" >&2
    exit 1
  fi
}

require_command terraform
require_command jq
require_command gcloud
require_command consul "Install it with: brew install consul"
if [ "$SKIP_BACKEND" != true ]; then
  require_command kubectl
  require_command helm
  require_command docker
fi
require_command dot "Install it with: brew install graphviz"

echo "=== 1. Starting local Consul dev agent ==="
CONSUL_STARTED=false
if pgrep -f "consul agent -dev" > /dev/null; then
  echo "Already running; preserving existing KV data."
else
  consul agent -dev > /tmp/consul-dev.log 2>&1 &
  CONSUL_STARTED=true
fi
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500

consul_ready=false
attempt=1
while [ "$attempt" -le 10 ]; do
  if consul members > /dev/null 2>&1; then
    consul_ready=true
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done
if [ "$consul_ready" != true ]; then
  echo "ERROR: local Consul agent did not become ready at $CONSUL_HTTP_ADDR." >&2
  if [ -f /tmp/consul-dev.log ]; then
    cat /tmp/consul-dev.log >&2
  fi
  exit 1
fi
if [ "$CONSUL_STARTED" = true ]; then
  echo "Started fresh and verified ready (log: /tmp/consul-dev.log)."
else
  echo "Verified local Consul is ready."
fi

if [ "$REFRESH_CONSUL" = true ]; then
  echo "Refreshing local Consul KV data by request."
  if command -v consul > /dev/null 2>&1; then
    consul kv delete -recurse "gitlab/terraform_outputs/" || true
  else
    echo "Warning: consul binary not found in PATH; cannot refresh KV data." >&2
    exit 1
  fi
fi

echo ""
echo "=== 2. Checking gcloud auth ==="
if ! gcloud auth application-default print-access-token > /dev/null 2>&1; then
  echo "No valid Application Default Credentials found — running login."
  gcloud auth application-default login
else
  echo "ADC already valid."
fi

state_path() {
  dir=$1
  workspace=$2
  if [ "$workspace" = "default" ]; then
    printf '%s/%s/terraform.tfstate' "$SCRIPT_DIR" "$dir"
  else
    printf '%s/%s/terraform.tfstate.d/%s/terraform.tfstate' "$SCRIPT_DIR" "$dir" "$workspace"
  fi
}

is_potentially_billable() {
  case "$1" in
    google_artifact_registry_repository|google_cloudfunctions2_function|google_compute_global_address|google_compute_router_nat|google_container_cluster|google_container_node_pool|google_dns_managed_zone|google_secret_manager_secret_version|google_sql_database_instance) return 0 ;;
    *) return 1 ;;
  esac
}

count_create_actions() {
  plan_file=$1
  resource_types=""
  resource_type=""

  resource_types=$(terraform show -json "$plan_file" | jq -r '.resource_changes[]? | select(.change.actions == ["create"]) | .type')
  while IFS= read -r resource_type; do
    [ -z "$resource_type" ] && continue
    if is_potentially_billable "$resource_type"; then
      BILLABLE_ADDED=$((BILLABLE_ADDED + 1))
    else
      FREE_ADDED=$((FREE_ADDED + 1))
    fi
  done <<< "$resource_types"
}

apply_repo() {
  dir=$1
  label=$2
  workspace=${3:-default}
  state=""
  plan_status=""
  address=""
  replace_args=""
  state_list_file=""
  plan_file=""

  state=$(state_path "$dir" "$workspace")
  echo ""
  echo "=== Applying $label ==="
  cd "$dir" || exit 1
    terraform init -input=false
    if [ "$workspace" != "default" ]; then
      terraform workspace select "$workspace" 2>/dev/null || terraform workspace new "$workspace"
    fi

    if [ ! -f "$state" ] && [ "$BOOTSTRAP" != true ]; then
      echo "ERROR: Terraform state is missing: $dir/${state##*/}" >&2
      echo "Refusing to create infrastructure from scratch." >&2
      echo "Recover the state or rerun with --bootstrap for intentional first setup." >&2
      exit 1
    fi

    if [ "$BOOTSTRAP" != true ] && [ ! -f "$CLEAN_DESTROY_MARKER" ] && [ -z "$(terraform state list 2>/dev/null)" ]; then
      echo "ERROR: Terraform state contains no tracked resources without a clean-destroy marker: $state" >&2
      echo "Refusing to recreate infrastructure because state may have been lost." >&2
      echo "Recover/import live resources, or use --bootstrap for an intentional first setup." >&2
      exit 1
    fi

    if [ "$CONSUL_STARTED" = true ] || [ "$REFRESH_CONSUL" = true ]; then
      state_list_file=$(mktemp)
      terraform state list > "$state_list_file" 2>/dev/null || true
      while IFS= read -r address; do
        case "$address" in
          consul_keys.publish_outputs*) replace_args="$replace_args -replace=$address" ;;
        esac
      done < "$state_list_file"
      rm -f "$state_list_file"
    fi

    plan_file=$(mktemp "${TMPDIR:-/tmp}/acme-terraform-plan.XXXXXX")
    set +e
    terraform plan -input=false -detailed-exitcode -out="$plan_file" $replace_args
    plan_status=$?
    set -e
    case "$plan_status" in
      0)
        rm -f "$plan_file"
        echo "$label is already in sync; no resources will be created."
        ;;
      2)
        count_create_actions "$plan_file"
        terraform apply -input=false -auto-approve "$plan_file"
        rm -f "$plan_file"
        ;;
      *)
        rm -f "$plan_file"
        echo "Terraform plan failed for $label." >&2
        exit "$plan_status"
        ;;
    esac
  cd "$SCRIPT_DIR" || exit 1
}

ensure_backend_image() {
  image=$(terraform -chdir="$SCRIPT_DIR/sample-program/infra" output -raw mock_backend_image)
  if gcloud artifacts docker images describe "$image" > /dev/null 2>&1; then
    echo "Backend image already exists: $image"
    return
  fi

  echo ""
  echo "=== Building backend learning image ==="
  if ! docker info > /dev/null 2>&1; then
    echo "ERROR: Docker is required to rebuild the backend image after a clean destroy." >&2
    echo "Start Docker Desktop, then rerun ./restore-session.sh." >&2
    exit 1
  fi
  registry=${image%%/*}
  gcloud auth configure-docker "$registry" --quiet
  docker buildx build --platform linux/amd64 --tag "$image" --push "$SCRIPT_DIR/backend/app"
}

ensure_backend_cluster_ready() {
  echo ""
  echo "=== Checking GKE nodes before applying backend ==="
  if ! command -v kubectl > /dev/null 2>&1; then
    echo "ERROR: kubectl is required to verify that the GKE cluster has nodes." >&2
    exit 1
  fi

  if command -v gcloud > /dev/null 2>&1; then
    gcloud container clusters get-credentials sample-program-np \
      --zone=us-central1-a > /dev/null
  fi

  attempt=1
  ready_nodes=""
  while [ "$attempt" -le 30 ]; do
    nodes=$(kubectl get nodes --no-headers 2>/tmp/acme-kubectl-error || true)
    ready_nodes=$(printf '%s\n' "$nodes" | awk '$2 ~ /^Ready/ {print}')
    [ -n "$ready_nodes" ] && break
    sleep 10
    attempt=$((attempt + 1))
  done
  if [ -z "$ready_nodes" ]; then
    echo "ERROR: no Ready GKE nodes are reachable." >&2
    echo "The backend Helm release waits for a scheduled pod and will otherwise time out." >&2
    echo "Check: kubectl get nodes --request-timeout=10s" >&2
    if [ -s /tmp/acme-kubectl-error ]; then
      cat /tmp/acme-kubectl-error >&2
    elif [ -n "$nodes" ]; then
      printf '%s\n' "$nodes" >&2
    fi
    exit 1
  fi

  printf '%s\n' "$ready_nodes"
}

generate_graph() {
  dir=$1
  label=$2
  workspace=${3:-default}

  echo ""
  echo "=== Generating $label Terraform graph ==="
  cd "$dir" || exit 1
    if [ "$workspace" != "default" ]; then
      terraform workspace select "$workspace" > /dev/null
    fi
    terraform graph -type=plan > graph.dot
    dot -Tsvg graph.dot -o graph.svg
    echo "Generated $dir/graph.dot and $dir/graph.svg."
  cd "$SCRIPT_DIR" || exit 1
}

repair_failed_helm_release() {
  helm_status=""
  if ! command -v helm > /dev/null 2>&1; then
    echo "ERROR: helm is required for --repair-failed-helm." >&2
    exit 1
  fi

  helm_status=$(helm status acme-sampleapp-backend \
    --namespace acme-sampleapp-backend-dev 2>&1 || true)
  case "$helm_status" in
    *"STATUS: failed"*)
      echo "Removing orphaned failed Helm release before Terraform apply."
      helm uninstall acme-sampleapp-backend \
        --namespace acme-sampleapp-backend-dev
      ;;
    *"release: not found"*|*"Release not loaded"*)
      ;;
    *)
      if [ -n "$helm_status" ]; then
        echo "$helm_status"
      fi
      ;;
  esac
}

echo ""
echo "=== 3. Applying the dependency graph ==="
echo "Existing state is preserved. GKE creation remains the billable step."
if [ "$BOOTSTRAP" = true ]; then
  echo "WARNING: --bootstrap is enabled; missing state may cause infrastructure creation."
fi
printf '%s' "Press enter to continue, or Ctrl+C to abort..."
read -r _

apply_repo "sample-program/infra" "sample-program (VPC, GKE, DNS)"
apply_repo "infrastructure/infra" "infrastructure (SSO secrets)"

if [ "$SKIP_BACKEND" = true ]; then
  echo "Backend skipped by request."
else
  ensure_backend_image
  ensure_backend_cluster_ready
  if [ "$REPAIR_FAILED_HELM" = true ]; then
    repair_failed_helm_release
  fi
  apply_repo "backend/infra" "backend (dev workspace)" "dev"
fi

if ! command -v dot > /dev/null 2>&1; then
  echo "ERROR: Graphviz dot is required to generate Terraform graph SVGs." >&2
  exit 1
fi

generate_graph "sample-program/infra" "sample-program"
generate_graph "infrastructure/infra" "infrastructure"
generate_graph "backend/infra" "backend (dev workspace)" "dev"

if [ "$SKIP_BACKEND" != true ]; then
  rm -f "$CLEAN_DESTROY_MARKER"
fi

echo ""
echo "=== Restore complete ==="
printf 'Potentially billable Terraform resources added: %s\n' "$BILLABLE_ADDED"
printf 'No-direct-charge Terraform resources added: %s\n' "$FREE_ADDED"
echo "These are Terraform resource counts, not a price estimate. Usage-based services can still incur charges."
echo "Run ./destroy-all.sh when the learning session ends to stop cloud charges."
echo "cloudsql and frontend were not applied; run them manually when those milestones begin."
