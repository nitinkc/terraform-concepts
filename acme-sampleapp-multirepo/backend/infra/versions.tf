terraform {
  required_version = ">= 1.7, < 2.0"
  # Swapped to local for this sandbox — see sample-program/infra/versions.tf
  # for the same note. Real repo uses backend "gcs" {} (partial config).
  backend "local" {
    path = "terraform.tfstate"
  }
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.41.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8.0"
    }
    shell = {
      source  = "scottwinkler/shell"
      version = "~> 1.7"
    }
  }
}
