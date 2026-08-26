# ──────────────────────────────────────────────
# Shared SampleApp Secrets
# ──────────────────────────────────────────────

# Read access only; the secret container is owned by the infrastructure repo and
# is deliberately not read at plan time (a container with no versions would fail
# a google_secret_manager_secret_version data source on a fresh environment).
resource "google_secret_manager_secret_iam_member" "backend_sso_config" {
  project   = local.app_infra.project_id
  secret_id = local.app_infra.sso_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}

# ──────────────────────────────────────────────
# Cloud SQL Cross-Project IAM Access
# ──────────────────────────────────────────────

resource "google_project_iam_member" "backend_sql_access" {
  for_each = local.cloudsql_enabled ? toset([
    "roles/cloudsql.viewer",
    "roles/cloudsql.client",
    "roles/cloudsql.instanceUser",
  ]) : toset([])

  project = local.cloudsql_project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_sql_user" "backend_sa" {
  count = local.cloudsql_enabled ? 1 : 0

  name     = trimsuffix(google_service_account.app.email, ".gserviceaccount.com")
  project  = local.cloudsql_project_id
  instance = local.cloudsql_instance_name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"

  depends_on = [google_project_iam_member.backend_sql_access]
}

# ──────────────────────────────────────────────
# Shell Script Bridge: DB-Level Permissions
# ──────────────────────────────────────────────
#
# The Cloud SQL module exposes grant/revoke Cloud Functions rather than a
# Terraform resource, so this is the supported way to hand the service account
# its in-database roles. `modify` grants DML/DDL on objects owned by the schema
# role; `readonly` is what carries CONNECT.

data "google_client_openid_userinfo" "current" {}

resource "shell_script" "backend_sa_sql_access" {
  count = local.cloudsql_enabled && local.cloudsql_grant_url != "" ? 1 : 0

  lifecycle_commands {
    create = <<EOF
#!/usr/bin/env bash
set -euo pipefail

echo "=== Starting database permission grant ==="
echo "User: ${google_sql_user.backend_sa[0].name}"

curlOut="$(curl -s \
  -H "Authorization: Bearer ${data.google_client_config.default.access_token}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "{\"audience\": \"$${GRANT_URL}\", \"includeEmail\": true}" \
  "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${data.google_client_openid_userinfo.current.email}:generateIdToken")"

ID_TOKEN="$(echo "$curlOut" | jq -r '.token')"

if [ -z "$ID_TOKEN" ] || [ "$ID_TOKEN" == "null" ]; then
  echo "ERROR: Failed to generate ID token"
  exit 1
fi

RES_MODIFY="$(curl -s \
  -H "Authorization: Bearer $${ID_TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"role": "modify", "user": "${google_sql_user.backend_sa[0].name}"}' \
  "$${GRANT_URL}")"
echo "Grant modify response: $RES_MODIFY"

RES_READONLY="$(curl -s \
  -H "Authorization: Bearer $${ID_TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"role": "readonly", "user": "${google_sql_user.backend_sa[0].name}"}' \
  "$${GRANT_URL}")"
echo "Grant readonly response: $RES_READONLY"

printf '{"response": %s}' "$(echo "$RES_MODIFY" | jq -c .)"
echo "=== Database permission grant completed ==="
EOF

    delete = <<EOF
#!/usr/bin/env bash
set -euo pipefail

echo "=== Starting database permission revoke ==="
echo "User: ${google_sql_user.backend_sa[0].name}"

curlOut="$(curl -s \
  -H "Authorization: Bearer ${data.google_client_config.default.access_token}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "{\"audience\": \"$${REVOKE_URL}\", \"includeEmail\": true}" \
  "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${data.google_client_openid_userinfo.current.email}:generateIdToken")"

ID_TOKEN="$(echo "$curlOut" | jq -r '.token')"

if [ -z "$ID_TOKEN" ] || [ "$ID_TOKEN" == "null" ]; then
  echo "ERROR: Failed to generate ID token"
  exit 1
fi

RES_MODIFY="$(curl -s \
  -H "Authorization: Bearer $${ID_TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"role": "modify", "user": "${google_sql_user.backend_sa[0].name}"}' \
  "$${REVOKE_URL}")"
echo "Revoke modify response: $RES_MODIFY"

RES_READONLY="$(curl -s \
  -H "Authorization: Bearer $${ID_TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"role": "readonly", "user": "${google_sql_user.backend_sa[0].name}"}' \
  "$${REVOKE_URL}")"
echo "Revoke readonly response: $RES_READONLY"

printf '{"response": %s}' "$(echo "$RES_MODIFY" | jq -c .)"
echo "=== Database permission revoke completed ==="
EOF

    read = <<EOF
#!/usr/bin/env bash
echo "{\"status\": \"user access is configured\"}"
EOF
  }

  environment = {
    GRANT_URL  = local.cloudsql_grant_url
    REVOKE_URL = local.cloudsql_revoke_url
  }

  triggers   = { user = google_sql_user.backend_sa[0].name }
  depends_on = [google_sql_user.backend_sa, google_project_iam_member.backend_sql_access]
}
