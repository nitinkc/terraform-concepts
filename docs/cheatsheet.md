


```terraform
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "> 2.4.1"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7.0" # Enforce version to avoid breaking changes
    }
  }
}

provider "local" {
  # Configuration options
}

provider "google" {
  project = "your-gcp-project-id"
  region  = "us-central1"
  zone    = "us-central1-a"
}

# 1st String - fixed resource name 
# 2nd String - user defined resource name
resource "local_file" "pet" {
  # Referencing Variable
  filename = var.fileName   

  # Resource attribute ${random_pet.my_pet.id}
  content  =  data.local_file.my_file.content

  # Change implementation
  file_permission = "0700"
  
  # Explicit dependency, Redundant , can be ignore where implicit, used for certain cases
  depends_on = [
    random_pet.my_pet
  ]

  lifecycle {
    # create_before_destroy = true # Stand the replacement up before tearing the old one down 
    # prevent_destroy = true # Hard-fail any plan that would delete this resource 
    # ignore_changes = all # top drift on the listed attributes from triggering an update
    ignore_changes = [
      file_permission,
    ]
    # replace_triggered_by : Force replacement when another resource changes
  }
}

# Sensitive Information, hide using sensitive=true
resource "local_file" "config" {
  filename = "/tmp/app-config.txt"
  content  = "token=${var.api_token}" #Sensitive Information 
}

# referencing locals via "local"
resource "local_file" "computed" {
  filename = "${local.base_dir}/greeting-${local.timestamp_suffix}.txt"
  content  = local.full_greeting
}

variable "fileName" {
  description = "The path where the file will be created"
  type        = string
  default     = "/tmp/helloFruits.txt"
}

variable "name_length" {
  description = "The length of the random pet name"
  type        = number
  default     = 1
  # Validation
  validation {
    condition     = var.name_length >= 1 && var.name_length <= 5
    error_message = "name_length must be between 1 and 5."
  }
}

variable "api_token" {
  description = "A fake secret, for practicing sensitive handling."
  type        = string
  default     = "super-secret-value-123"
  sensitive   = true #Sensitive Information, hide using sensitive=true
}


locals {
  timestamp_suffix = formatdate("YYYYMMDD", timestamp())
  base_dir         = "/tmp/tf-practice-locals"
  # Resource Attribute
  full_greeting    = "Hello from ${random_pet.my_pet.id}! Generated on ${local.timestamp_suffix}."
}

# For Random Pet - https://registry.terraform.io/providers/hashicorp/random/3.9.0/docs/resources/pet
resource "random_pet" "my_pet" {
  prefix    = var.prefix
  separator = var.separator
  length    = var.name_length
  
}

data "local_file" "my_file"{
  filename = "/tmp/my_file.txt"
}

output "pet_id" {
  description = "The generated random pet name/id."
  value       = random_pet.my_pet.id
}
```

`depends_on` earns its place only when the dependency is real but invisible to HCL:

- IAM permissions that must propagate before the resource using them is created
- a `null_resource` script that must run first
- an API that must be enabled before anything can call it

There's a real example of the IAM case in
[`backend/infra/main.tf`](https://github.com/nitinkc/terraform-concepts/blob/main/acme-sampleapp-multirepo-sandbox-elaborate/backend/infra/main.tf)
in the sandbox, and the GCP version of the implicit case is


```shell
# Workflow
terraform init          # Download providers & initialize backend (-upgrade to update)
terraform validate      # Check syntax and internal consistency
terraform fmt -recursive # Format all .tf files to canonical style
terraform plan -out=tfplan # Preview execution plan
terraform apply tfplan  # Apply the saved plan (or 'terraform apply -auto-approve')
terraform destroy       # Tear down all managed infrastructure

# Targeting & Selective Replace
terraform apply -target=local_file.pet   # Apply ONLY a specific resource
terraform apply -replace=local_file.pet  # Force recreation of a specific resource

# State Inspection & Management
terraform state list                     # List all resources in state
terraform state show local_file.pet      # View details of a specific resource in state
terraform state mv <source> <dest>       # Rename resource without destroying/recreating
terraform state rm <resource_address>    # Remove from state without deleting real infra
terraform import <address> <remote_id>   # Bring existing infrastructure under TF management

# Debugging & Workspaces
terraform console       # Interactive REPL for testing functions & expressions
terraform workspace list / select / new  # Manage multiple state environments (dev/prod)

```