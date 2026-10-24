variable "project_id" {
  description = "The name of the GCP project"
  type        = string
  default     = "my-devops-journey-502420" # Replace with your real GCP Project ID
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-a"
}


variable "environment_list" {
  type    = list(string)
  default = ["dev", "staging"]
}

variable "environment_set" {
  type    = set(string)
  default = ["int", "stg"]
}

# Step 13 For-each over modules
variable "service_accounts" {
  type = map(object({
    account_id   = string
    display_name = string
  }))
  default = {
    dev = {
      account_id   = "acme-dev-app"
      display_name = "Dev App SA"
    }
    stg = {
      account_id   = "acme-stg-app"
      display_name = "Staging App SA"
    }
  }
}
