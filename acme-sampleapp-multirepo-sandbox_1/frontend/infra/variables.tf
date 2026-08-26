variable "docker_image_repo" {
  type        = string
  description = "Frontend container image repository"
}

variable "docker_image_tag" {
  type        = string
  description = "Frontend container image tag"
  default     = "latest"
}

variable "static_env" {
  type        = bool
  description = "Boolean set to true if workspace is a static environment"
  default     = false
}

variable "sampleapp_ops_ad_group" {
  type        = string
  description = "AD group granted namespace RBAC for the frontend, same convention as backend/infra"
  default     = "gcp-digital-experience-ops@acme.com"
}
