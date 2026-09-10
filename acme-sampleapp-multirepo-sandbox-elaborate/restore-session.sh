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

The default mode is a safe resume: it preserves local Consul data and refuses
an apply when a Terraform state file is missing, preventing an accidental
recreation of the sandbox.
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

echo "=== 1. Starting local Consul dev agent ==="
CONSUL_STARTED=false
if pgrep -f "consul agent -dev" > /dev/null; then
  echo "Already running; preserving existing KV data."
else
  consul agent -dev > /tmp/consul-dev.log 2>&1 &
  CONSUL_STARTED=true
  sleep 2
  echo "Started fresh (log: /tmp/consul-dev.log)."
fi
export CONSUL_HTTP_ADDR=http://127.0.0.1:8500

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

  nodes=$(kubectl get nodes --no-headers 2>/tmp/acme-kubectl-error || true)
  ready_nodes=$(printf '%s\n' "$nodes" | awk '$2 ~ /^Ready/ {print}')
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

echo ""
echo "=== Done. ==="
echo "The Acme learning sandbox was resumed without clearing Terraform state."
echo "cloudsql and frontend were not applied; run them manually when ready."
