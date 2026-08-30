# ──────────────────────────────────────────────
# Consul Data Sources
# ──────────────────────────────────────────────

data "consul_keys" "remote_outputs" {
  key {
    name = "program"
    path = "gitlab/terraform_outputs/v2/sample-org/sample-program/default"
  }
  key {
    name = "infrastructure"
    path = "gitlab/terraform_outputs/v2/sample-org/applications/acme-sampleapp/infrastructure/default"
  }
  key {
    name = "cloudsql"
    # Permanent environments (dev, qa, default) use their own Cloud SQL.
    # Non-permanent (review) environments borrow dev's instance for testing.
    path = "gitlab/terraform_outputs/v2/sample-org/applications/acme-sampleapp/cloudsql/${contains(local.permanent_envs, terraform.workspace) ? terraform.workspace : "dev"}"
  }
}

# ──────────────────────────────────────────────
# Local Variables
# ──────────────────────────────────────────────

locals {
  # the map is empty because no GKE cluster was ever created (enable_gke_p/enable_gke_np are still false).
  # This is backend/infra correctly failing fast rather than silently limping forward with missing data
  p_or_np       = terraform.workspace == "default" ? "p" : "np"
  program_gcp   = jsondecode(data.consul_keys.remote_outputs.var.program).outputs.gcp.us_central1[local.p_or_np]
  is_review_env = terraform.workspace != "default" && !var.static_env

  static_envs    = ["dev", "qa"]
  permanent_envs = concat(local.static_envs, ["default"])

  workspace_suffix = trimsuffix(substr(terraform.workspace, 0, 10), "-")
  namespace_name   = "acme-sampleapp-backend${terraform.workspace == "default" ? "" : "-${local.workspace_suffix}"}"
  backend_sa_name  = "acme-sampleapp-backend-sa"

  # Shared SampleApp project/secrets. That repo runs a single `default`
  # workspace and keys its outputs by environment name, so map this workspace
  # onto one of those keys. Review environments fall back to dev.
  infra_env_key = terraform.workspace == "default" ? "prod" : contains(local.static_envs, terraform.workspace) ? terraform.workspace : "dev"
  app_infra      = jsondecode(data.consul_keys.remote_outputs.var.infrastructure).outputs.gcp.us_central1[local.infra_env_key]

  # The frontend is served same-origin (its nginx proxies /api/ to this service
  # in-cluster), so CORS is only needed for direct browser calls. Scope it to the
  # frontend hostname rather than "*".
  frontend_host_name = trimsuffix("sampleapp${terraform.workspace == "default" ? "" : "-${local.workspace_suffix}"}.${local.program_gcp.dns.public_zone.dns_name}", ".")

  sampleapp_ops_ad_group = var.sampleapp_ops_ad_group
}

# ──────────────────────────────────────────────
# Core Kubernetes Infrastructure
# ──────────────────────────────────────────────

resource "random_string" "suffix" {
  count   = local.is_review_env ? 1 : 0
  length  = 4
  special = false
  upper   = false
}

resource "kubernetes_namespace_v1" "main" {
  metadata {
    name = local.namespace_name
    labels = {
      "networking/namespace" = local.namespace_name
      "cluster"              = local.program_gcp.gke.name
      "project"               = local.program_gcp.gke.project
      "region"                = "us-central1"
    }
  }
  lifecycle {
    ignore_changes = [metadata[0].labels["dynakube.internal.dynatrace.com/instance"]]
  }
}

resource "google_service_account" "app" {
  project      = local.program_gcp.gke.project
  account_id   = "sa-backend${terraform.workspace == "default" ? "" : "-${local.workspace_suffix}"}${local.is_review_env ? "-${try(random_string.suffix[0].result, "")}" : ""}"
  display_name = "Acme SampleApp Backend (${local.namespace_name})"
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.program_gcp.gke.project}.svc.id.goog[${kubernetes_namespace_v1.main.metadata[0].name}/${local.backend_sa_name}]"
}

# ──────────────────────────────────────────────
# Helm Release: Deployment
# ──────────────────────────────────────────────

resource "helm_release" "acme_sampleapp_backend" {
  name      = "acme-sampleapp-backend"
  chart     = "${path.module}/../charts/acme-sampleapp-backend"
  namespace = kubernetes_namespace_v1.main.metadata[0].name
  timeout   = 600

  values = [
    file("${path.module}/../charts/acme-sampleapp-backend/values${terraform.workspace == "default" ? "-prod" : contains(local.static_envs, terraform.workspace) ? "-${terraform.workspace}" : "-dev"}.yaml"),
    yamlencode({
      serviceAccount = {
        create = true
        name   = local.backend_sa_name
        annotations = {
          "iam.gke.io/gcp-service-account" = google_service_account.app.email
        }
      }
      cloudSql = {
        enabled        = local.cloudsql_enabled
        projectId      = local.cloudsql_project_id
        region         = local.cloudsql_region
        instanceName   = local.cloudsql_instance_name
        connectionName = local.cloudsql_connection_name
        database       = local.cloudsql_database_name
        user           = local.cloudsql_enabled ? try(google_sql_user.backend_sa[0].name, "") : ""
        schema         = local.cloudsql_db_schema
      }
      backend = {
        image = {
          repository = var.docker_image_repo
          tag        = var.docker_image_tag
        }
        env = [
          {
            name  = "ENVIRONMENT"
            value = terraform.workspace == "default" ? "prod" : terraform.workspace
          },
          {
            # The chart only emits DATABASE_URL when cloudSql.enabled is true, so
            # fall back to the app's built-in mock data until the database for
            # this workspace exists.
            name  = "USE_MOCK_DATA"
            value = local.cloudsql_enabled ? "false" : "true"
          },
          {
            name  = "ALLOWED_ORIGINS"
            value = "https://${local.frontend_host_name}"
          },
        ]
      }
    })
  ]

  # shell_script.backend_sa_sql_access is included deliberately: it carries the
  # in-database grant, and without it Helm can start pods before the service
  # account can read its own schema, which crashloops until the next reconcile.
  # The reference repos omit this and have that race.
  depends_on = [
    google_project_iam_member.backend_sql_access,
    google_service_account_iam_member.workload_identity,
    shell_script.backend_sa_sql_access,
  ]
}
