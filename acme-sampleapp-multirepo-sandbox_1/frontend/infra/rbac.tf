# Simpler than backend/infra/rbac.tf: the frontend namespace holds no secrets
# worth a dynamic non-prod rule, and pods/exec is rarely needed against a
# static nginx container. Read-only visibility plus basic troubleshooting
# access is enough, kept as its own Role (rather than reusing backend's) so
# the two team roles can diverge independently as each app's needs change.

resource "kubernetes_role_v1" "sampleapp_team" {
  metadata {
    name      = "acme-sampleapp-frontend-team"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "endpoints", "events"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "sampleapp_team" {
  metadata {
    name      = "acme-sampleapp-frontend-team"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = var.sampleapp_ops_ad_group
    api_group = "rbac.authorization.k8s.io"
  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role_v1.sampleapp_team.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}
