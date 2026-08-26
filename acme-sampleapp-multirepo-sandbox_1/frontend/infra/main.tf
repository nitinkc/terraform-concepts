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
    name = "backend"
    path = "gitlab/terraform_outputs/v2/sample-org/applications/acme-sampleapp/backend/${terraform.workspace}"
  }
}

locals {
  p_or_np       = terraform.workspace == "default" ? "p" : "np"
  program_gcp   = jsondecode(data.consul_keys.remote_outputs.var.program).outputs.gcp.us_central1[local.p_or_np]
  is_review_env = terraform.workspace != "default" && !var.static_env

  static_envs = ["dev", "qa"]

  workspace_suffix = trimsuffix(substr(terraform.workspace, 0, 10), "-")
  namespace_name    = "acme-sampleapp-frontend${terraform.workspace == "default" ? "" : "-${local.workspace_suffix}"}"
  frontend_sa_name  = "acme-sampleapp-frontend-sa"

  infra_env_key = terraform.workspace == "default" ? "prod" : contains(local.static_envs, terraform.workspace) ? terraform.workspace : "dev"
  app_infra     = jsondecode(data.consul_keys.remote_outputs.var.infrastructure).outputs.gcp.us_central1[local.infra_env_key]

  # The backend publishes its own in-cluster service URL so the frontend never
  # hardcodes it — mirrors backend/infra's own consumption of the cloudsql
  # repo's outputs. Falls back to "" if the backend hasn't been applied yet in
  # this workspace, so this repo can be planned independently.
  backend_url = try(jsondecode(data.consul_keys.remote_outputs.var.backend).backend_service_url, "")
}

resource "kubernetes_namespace_v1" "main" {
  metadata {
    name = local.namespace_name
    labels = {
      "networking/namespace" = local.namespace_name
      "cluster"              = local.program_gcp.gke.name
      "project"               = local.program_gcp.gke.project
    }
  }
}

resource "helm_release" "acme_sampleapp_frontend" {
  name      = "acme-sampleapp-frontend"
  chart     = "${path.module}/../charts/acme-sampleapp-frontend"
  namespace = kubernetes_namespace_v1.main.metadata[0].name
  timeout   = 600

  values = [
    file("${path.module}/../charts/acme-sampleapp-frontend/values${terraform.workspace == "default" ? "-prod" : contains(local.static_envs, terraform.workspace) ? "-${terraform.workspace}" : "-dev"}.yaml"),
    yamlencode({
      serviceAccount = {
        create = true
        name   = local.frontend_sa_name
        annotations = {
          "iam.gke.io/gcp-service-account" = google_service_account.app.email
        }
      }
      frontend = {
        image = {
          repository = var.docker_image_repo
          tag        = var.docker_image_tag
        }
        env = [
          { name = "API_BASE_URL", value = local.backend_url },
          # sso_client_id is non-sensitive (public OAuth client identifier),
          # so it's read straight out of the infrastructure repo's Consul
          # outputs here rather than via a Secret Manager grant — see
          # frontend/infra/iam.tf's header comment for why.
          { name = "SSO_CLIENT_ID", value = try(local.app_infra.sso_client_id, "") },
        ]
      }
      ingress = {
        host         = local.host_name
        tls          = true
        staticIpName = google_compute_global_address.frontend_vip.name
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.main,
    google_service_account_iam_member.workload_identity,
  ]
}
