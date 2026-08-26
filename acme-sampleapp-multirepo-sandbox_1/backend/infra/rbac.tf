resource "random_id" "role_suffix" {
  byte_length = 4
}

resource "kubernetes_role_v1" "sampleapp_team" {
  metadata {
    name      = "acme-sampleapp-backend-team-${random_id.role_suffix.hex}"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "persistentvolumes", "persistentvolumeclaims", "endpoints", "events", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/exec", "pods/portforward"]
    verbs      = ["create"]
  }
  rule {
    api_groups = [""]
    resources  = ["services/proxy"]
    verbs      = ["get", "create"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "update", "patch", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets"]
    verbs      = ["get", "list", "update", "patch", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["batch"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["autoscaling"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
  # Secret read access is non-prod only — prod secrets stay out of reach of the
  # team role.
  dynamic "rule" {
    for_each = terraform.workspace != "default" ? [1] : []
    content {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["get", "list", "watch"]
    }
  }
}

resource "kubernetes_role_binding_v1" "sampleapp_team" {
  metadata {
    name      = "acme-sampleapp-backend-team"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = local.sampleapp_ops_ad_group
    api_group = "rbac.authorization.k8s.io"
  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role_v1.sampleapp_team.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}
