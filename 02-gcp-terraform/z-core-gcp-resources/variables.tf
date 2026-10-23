variable "project_id" {
  description = "The name of the GCP project"
  type        = string
  default     = "my-devops-journey-502420" # Replace with your real GCP Project ID
}

variable "environments" {
  # type    = list(string)
  type    = set(string)
  default = ["dev", "staging"]
}

