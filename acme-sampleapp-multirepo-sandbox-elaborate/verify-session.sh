#!/bin/sh
# verify-session.sh — read-only health check for the Acme learning sandbox.
# Run from any directory. Use --plans to add Terraform refresh/plan checks.

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR" || exit 1

RUN_PLANS=false
FAILURES=0
WARNINGS=0
TMP_DIR=${TMPDIR:-/tmp}/acme-verify-$$
mkdir "$TMP_DIR" || exit 1
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

if [ "${1:-}" = "--plans" ]; then
  RUN_PLANS=true
elif [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<'EOF'
Usage: ./verify-session.sh [--plans]

Read-only checks:
  - required command-line tools and Google ADC
  - local Consul agent and published cross-repo keys
  - GKE cluster, node pool, endpoint, and Ready nodes
  - backend namespace, deployment, ReplicaSet, pod, events, and Helm release
  - Terraform state files for every Acme root

--plans also runs terraform plan in sample-program, infrastructure, and the
backend dev workspace. Plan exit code 2 is reported as a warning because it
means Terraform found changes; exit code 1 is reported as a failure.
EOF
  exit 0
elif [ "$#" -gt 0 ]; then
  echo "Unknown option: $1" >&2
  exit 2
fi

pass() {
  printf 'PASS  %s\n' "$1"
}

warn() {
  printf 'WARN  %s\n' "$1"
  WARNINGS=$((WARNINGS + 1))
}

fail() {
  printf 'FAIL  %s\n' "$1"
  FAILURES=$((FAILURES + 1))
}

command_check() {
  label=$1
  command_name=$2
  if command -v "$command_name" > /dev/null 2>&1; then
    pass "$label ($command_name)"
  else
    fail "$label ($command_name is not installed)"
  fi
}

run_check() {
  label=$1
  shift
  output=$("$@" 2>&1)
  status=$?
  if [ "$status" -eq 0 ]; then
    pass "$label"
    [ -n "$output" ] && printf '%s\n' "$output"
  else
    fail "$label"
    [ -n "$output" ] && printf '%s\n' "$output" >&2
  fi
  return 0
}

plan_check() {
  label=$1
  dir=$2
  workspace=$3
  plan_log="$TMP_DIR/$(printf '%s' "$label" | tr ' /' '__').log"

  if ! cd "$SCRIPT_DIR/$dir"; then
    fail "$label directory exists"
    return 0
  fi
  terraform init -input=false > /dev/null 2>&1 || {
    fail "$label Terraform initialization"
    cd "$SCRIPT_DIR" || exit 1
    return 0
  }
  if [ "$workspace" != "default" ]; then
    terraform workspace select "$workspace" > /dev/null 2>&1 || {
      fail "$label workspace $workspace exists"
      cd "$SCRIPT_DIR" || exit 1
      return 0
    }
  fi

  terraform plan -input=false -no-color -detailed-exitcode > "$plan_log" 2>&1
  status=$?
  case "$status" in
    0) pass "$label Terraform plan has no changes" ;;
    2)
      warn "$label Terraform plan found changes"
      awk '/^Plan:|^Error:|^Warning:/{print}' "$plan_log"
      ;;
    *)
      fail "$label Terraform plan failed"
      awk '/^Plan:|^Error:|^Warning:|^│/{print}' "$plan_log" | tail -40
      ;;
  esac
  cd "$SCRIPT_DIR" || exit 1
}

echo "=== Acme sandbox verification ==="
printf 'Root: %s\n\n' "$SCRIPT_DIR"

echo "--- Local tools and authentication ---"
command_check "Terraform" terraform
command_check "gcloud" gcloud
command_check "kubectl" kubectl
command_check "Helm" helm
command_check "Consul" consul
run_check "Google Application Default Credentials" sh -c \
  'gcloud auth application-default print-access-token > /dev/null'

if command -v consul > /dev/null 2>&1; then
  export CONSUL_HTTP_ADDR=http://127.0.0.1:8500
  run_check "Local Consul agent" consul members
  echo ""
  echo "--- Consul contracts ---"
  run_check "sample-program output" sh -c \
    'consul kv get "$1" > /dev/null' sh \
    "gitlab/terraform_outputs/v2/sample-org/sample-program/default"
  run_check "infrastructure dev output" sh -c \
    'consul kv get "$1" > /dev/null' sh \
    "gitlab/terraform_outputs/v2/sample-org/applications/acme-sampleapp/infrastructure/dev"
  run_check "infrastructure qa output" sh -c \
    'consul kv get "$1" > /dev/null' sh \
    "gitlab/terraform_outputs/v2/sample-org/applications/acme-sampleapp/infrastructure/qa"
  run_check "backend dev output" sh -c \
    'consul kv get "$1" > /dev/null' sh \
    "gitlab/terraform_outputs/v2/sample-org/applications/acme-sampleapp/backend/dev"
fi

echo ""
echo "--- Terraform state files ---"
for root in sample-program infrastructure cloudsql backend frontend; do
  state="$SCRIPT_DIR/$root/infra/terraform.tfstate"
  if [ "$root" = "backend" ]; then
    state="$SCRIPT_DIR/$root/infra/terraform.tfstate.d/dev/terraform.tfstate"
  fi
  if [ -f "$state" ]; then
    pass "$root state exists"
  else
    warn "$root state is missing or not yet applied"
  fi
done

if command -v gcloud > /dev/null 2>&1; then
  echo ""
  echo "--- GKE ---"
  run_check "GKE cluster is reachable through Google APIs" \
    gcloud container clusters describe sample-program-np \
      --project="$(gcloud config get-value project 2>/dev/null)" \
      --zone=us-central1-a \
      --format='value(status)'
  run_check "GKE node pool exists" sh -c \
    'test -n "$(gcloud container node-pools list \
      --cluster=sample-program-np \
      --project="$1" \
      --zone=us-central1-a \
      --format="value(name)")"' sh \
    "$(gcloud config get-value project 2>/dev/null)"
  run_check "Refresh local kubeconfig" \
    gcloud container clusters get-credentials sample-program-np \
      --zone=us-central1-a
fi

if command -v kubectl > /dev/null 2>&1; then
  echo ""
  echo "--- Kubernetes and Helm ---"
  run_check "Kubernetes API is reachable" sh -c \
    'kubectl get --raw=/version > /dev/null'
  run_check "At least one Ready node" sh -c \
    "kubectl get nodes --no-headers | awk '\$2 ~ /^Ready/ {found=1} END {exit(found ? 0 : 1)}'"
  if kubectl get namespace acme-sampleapp-backend-dev > /dev/null 2>&1; then
    pass "Backend namespace"
    run_check "Backend deployment" kubectl get deployment \
      acme-sampleapp-backend -n acme-sampleapp-backend-dev -o wide
    run_check "Backend deployment is available" kubectl rollout status deployment/acme-sampleapp-backend \
      -n acme-sampleapp-backend-dev --timeout=10s
    run_check "Backend ReplicaSet" kubectl get replicasets \
      -n acme-sampleapp-backend-dev -o wide
    run_check "Backend pods" kubectl get pods \
      -n acme-sampleapp-backend-dev -o wide
    echo "Recent backend events:"
    kubectl get events -n acme-sampleapp-backend-dev \
      --sort-by='.lastTimestamp' 2>&1 | tail -20
  else
    fail "Backend namespace"
    warn "Skipping backend workload checks because the namespace is absent"
  fi
fi

if command -v helm > /dev/null 2>&1; then
  run_check "Backend Helm release is deployed" sh -c \
    'helm status acme-sampleapp-backend --namespace acme-sampleapp-backend-dev -o json | grep -Eq '\''"status"[[:space:]]*:[[:space:]]*"deployed"'\'''
fi

if [ "$RUN_PLANS" = true ] && command -v terraform > /dev/null 2>&1; then
  echo ""
  echo "--- Terraform plans ---"
  plan_check "sample-program" sample-program/infra default
  plan_check "infrastructure" infrastructure/infra default
  plan_check "backend" backend/infra dev
fi

echo ""
echo "=== Verification summary ==="
printf 'Failures: %s\nWarnings: %s\n' "$FAILURES" "$WARNINGS"
if [ "$FAILURES" -gt 0 ]; then
  exit 1
fi
exit 0
