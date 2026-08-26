terraform {
  required_version = ">= 1.7, < 2.0"
  backend "gcs" {}
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.41.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "2.23.0"
    }
  }
}
