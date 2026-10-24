variable "sso_client_id" {
  type        = string
  description = "SSO client ID for the SampleApp application, stored alongside the client secret in Secret Manager"
}

variable "sso_client_secret" {
  type        = string
  description = "SSO client secret. Passed via TF_VAR at apply time (e.g. from CI/CD secret store) — never committed."
  sensitive   = true
}
