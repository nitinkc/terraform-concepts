variable "docker_image_repo" {
  type        = string
  description = "Backend container image repository"
}

variable "docker_image_tag" {
  type        = string
  description = "Backend container image tag"
  default     = "latest"
}

variable "static_env" {
  type        = bool
  description = "Boolean set to true if workspace is a static environment"
  default     = false
}

# TODO: Update this to the sampleapp ops group once created : Review with platform team
variable "sampleapp_ops_ad_group" {
  type        = string
  description = <<-EOT
    AD group granted namespace RBAC for SampleApp — this includes pods/exec,
    pods/portforward and pods/log, so members can reach a running container and
    the data flowing through it.

    Defaults to the platform ops group that every application in this estate
    currently shares. SampleApp is an independent application and is expected
    to move to its own group (e.g. gcp-sampleapp-ops@acme.com) once the
    platform team creates one — override TF_VAR_sampleapp_ops_ad_group at the
    CI/CD group level to switch, with no code change in any repo.
  EOT
  default     = "gcp-digital-experience-ops@acme.com"

  validation {
    condition     = can(regex("^[a-z0-9._-]+@acme\\.com$", var.sampleapp_ops_ad_group))
    error_message = "sampleapp_ops_ad_group must be an acme.com group address, e.g. gcp-sampleapp-ops@acme.com."
  }
}
