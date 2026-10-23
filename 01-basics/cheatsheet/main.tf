# ==============================================================================
# 1. TERRAFORM CONFIGURATION BLOCK & BACKEND
# ==============================================================================
terraform {
  # Minimum required Terraform CLI version
  required_version = ">= 1.5.0"

  # Remote State Storage (e.g., GCS, S3, or Local)
  # State locking prevents concurrent modifications
  backend "local" {
    path = "terraform.tfstate"
  }
  # backend "gcs" {
  #   bucket = "my-tf-state-bucket"
  #   prefix = "terraform/state"
  # }

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "> 2.4.1"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7.0" # Enforce version to avoid breaking changes (~> allows only patch/minor bumps)
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

# ==============================================================================
# 2. PROVIDERS & ALIASES (Multi-Region / Multi-Account)
# ==============================================================================
provider "local" {
  # Configuration options
}

# Default Provider
provider "google" {
  project = "your-gcp-project-id"
  region  = "us-central1"
  zone    = "us-central1-a"
}

# Aliased Provider (used for multiple regions, accounts, or credentials)
provider "google" {
  alias   = "europe"
  project = "your-gcp-project-id"
  region  = "europe-west1"
  zone    = "europe-west1-b"
}

# ==============================================================================
# 3. VARIABLES (Primitives, Complex Types, Validations)
# Precedence: CLI (-var / -var-file) > *.auto.tfvars > terraform.tfvars > TF_VAR_* > default
# ==============================================================================
variable "fileName" {
  description = "The path where the file will be created"
  type        = string
  default     = "/tmp/cheatsheet/helloFruits.txt"
}

variable "name_length" {
  description = "The length of the random pet name"
  type        = number
  default     = 1
  # Custom Validation Rule
  validation {
    condition     = var.name_length >= 1 && var.name_length <= 5
    error_message = "name_length must be between 1 and 5."
  }
}

variable "api_token" {
  description = "A fake secret, for practicing sensitive handling."
  type        = string
  default     = "super-secret-value-123"
  sensitive   = true # Sensitive Information, hide using sensitive=true (masks value in CLI output & logs)
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  nullable    = false # Rejects null values
}

# Complex Variable Types
variable "file_list" {
  description = "List of file identifiers"
  type        = list(string)
  default     = ["file1", "file2", "file3"]
}

variable "user_roles" {
  description = "Map of users and roles"
  type        = map(string)
  default = {
    alice = "admin"
    bob   = "viewer"
  }
}

variable "server_config" {
  description = "Structured object with optional fields and defaults (TF 1.3+)"
  type = object({
    instance_count = number
    tags           = list(string)
    enabled        = optional(bool, true) # optional with default
  })
  default = {
    instance_count = 2
    tags           = ["web", "api"]
  }
}

# ==============================================================================
# 4. LOCALS (Expressions, Built-in Functions, Transformations)
# ==============================================================================
locals {
  timestamp_suffix = formatdate("YYYYMMDD", timestamp())
  base_dir         = "/tmp/cheatsheet/tf-practice-locals"
  # Resource Attribute
  full_greeting    = "Hello from ${random_pet.my_pet.id}! Generated on ${local.timestamp_suffix}."

  # --- Conditionals & Ternary Operator ---
  is_prod          = var.environment == "prod" ? true : false
  app_tier         = var.environment == "prod" ? "high-performance" : "standard"

  # --- List Comprehensions (for expression) ---
  uppercase_files  = [for f in var.file_list : upper(f)]

  # --- Map Comprehensions with filtering (if clause) ---
  admin_users      = { for user, role in var.user_roles : user => role if role == "admin" }

  # --- Common Built-in Functions ---
  # Collection: merge, concat, flatten, lookup, element, coalesce, distinct
  merged_tags      = merge({ env = var.environment }, { project = "demo" })
  flattened_list   = flatten([[1, 2], [3, 4]])
  safe_role_lookup = lookup(var.user_roles, "charlie", "default-role") # Returns default if key missing
  first_non_empty  = coalesce("", "", "fallback_value")               # Returns first non-empty string

  # String & Encoding: split, join, lower, upper, replace, jsonencode, jsondecode
  csv_string       = join(",", var.file_list)
  json_payload     = jsonencode({ env = var.environment, count = var.server_config.instance_count })

  # Error Handling & Defensive Expressions
  # try: returns first expression that doesn't error
  safe_count       = try(var.server_config.instance_count, 1)
  # can: returns boolean (true if evaluation succeeds, false if error)
  has_valid_tag    = can(var.server_config.tags[0])
}

# ==============================================================================
# 5. DATA SOURCES (Reading Existing / External State)
# ==============================================================================
data "local_file" "my_file" {
  filename = "/tmp/cheatsheet/my_file.txt"
}

# ==============================================================================
# 6. RESOURCES (Core, Meta-Arguments, Lifecycle, Loops)
# ==============================================================================

# For Random Pet - https://registry.terraform.io/providers/hashicorp/random/3.9.0/docs/resources/pet
# 1st String - fixed resource name
# 2nd String - user defined resource name
resource "random_pet" "my_pet" {
  length = var.name_length
}

resource "local_file" "pet" {
  # Referencing Variable
  filename = var.fileName

  # Resource attribute ${random_pet.my_pet.id}
  content  = data.local_file.my_file.content

  # Change implementation
  file_permission = "0700"

  # Explicit dependency, Redundant , can be ignore where implicit, used for certain cases
  depends_on = [
    random_pet.my_pet
  ]

  lifecycle {
    # create_before_destroy = true # Stand the replacement up before tearing the old one down
    # prevent_destroy       = true # Hard-fail any plan that would delete this resource
    # ignore_changes        = all  # Stop drift on all listed attributes from triggering an update
    ignore_changes = [
      file_permission,
    ]
    # replace_triggered_by : Force replacement when another resource/attribute changes
    replace_triggered_by = [
      random_pet.my_pet.id
    ]

    # Preconditions / Postconditions (Custom checks at plan/apply time)
    precondition {
      condition     = var.fileName != ""
      error_message = "File name must not be empty."
    }
    postcondition {
      condition     = self.file_permission == "0700"
      error_message = "File permission must remain 0700."
    }
  }
}

# Sensitive Information, hide using sensitive=true
resource "local_file" "config" {
  filename = "/tmp/cheatsheet/app-config.txt"
  content  = "token=${var.api_token}" # Sensitive Information
}

# referencing locals via "local"
resource "local_file" "computed" {
  filename = "${local.base_dir}/greeting-${local.timestamp_suffix}.txt"
  content  = local.full_greeting
}

# --- Meta-argument: count (Index-based scaling) ---
# Creates multiple instances indexed as [0], [1], ...
resource "local_file" "counted" {
  count    = length(var.file_list)
  filename = "/tmp/cheatsheet/counted-${var.file_list[count.index]}.txt"
  content  = "Index number: ${count.index} for ${var.file_list[count.index]}"
}

# --- Meta-argument: for_each (Key/Value or Set-based scaling) ---
# Prefer for_each over count when items can be added/removed from the middle without shifting indices
resource "local_file" "keyed_map" {
  for_each = var.user_roles # Works on maps or toset(list)
  filename = "/tmp/cheatsheet/user-${each.key}.txt"
  content  = "User ${each.key} has role ${each.value}"
}

# --- Provisioners (Execute scripts/commands locally or remotely) ---
# Note: Use as a last resort when native resource attributes or cloud-init are insufficient
resource "null_resource" "example_provisioner" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "echo 'Terraform applied at $(date)' >> /tmp/cheatsheet/tf_apply.log"
    # when       = destroy # Run on destruction instead of creation
    # on_failure = continue # Do not fail terraform apply if command exits non-zero
  }
}

# ==============================================================================
# 7. MODULES (Reusable Configurations)
# ==============================================================================
# module "network" {
#   source = "./modules/network" # Local path, Git URL, or Terraform Registry
#   # version = "1.0.0"          # Required for Registry sources
#
#   # Passing inputs to module
#   vpc_name    = "my-vpc"
#   environment = var.environment
#
#   # Meta-arguments supported by modules:
#   # count      = 2
#   # for_each   = toset(["east", "west"])
#   # depends_on = [resource.local_file.pet]
#   # providers  = { google = google.europe } # Pass custom/aliased provider
# }

# ==============================================================================
# 8. OUTPUTS (Export Values & Cross-Module Communication)
# ==============================================================================
output "pet_id" {
  description = "The generated random pet name/id."
  value       = random_pet.my_pet.id
}

output "api_token_masked" {
  description = "Exporting sensitive data requires explicit sensitive = true"
  value       = var.api_token
  sensitive   = true # Prevents printing plaintext secret to stdout on terraform apply
}

output "all_counted_filenames" {
  description = "Splat expression [*] extracts an attribute across all count instances"
  value       = local_file.counted[*].filename
}

output "all_keyed_filenames" {
  description = "Values from for_each resources mapped via for expression"
  value       = [for f in local_file.keyed_map : f.filename]
}

# ==============================================================================
# 9. CHECKS (Terraform 1.5+ Continuous Infrastructure Assertions)
# ==============================================================================
check "health_check" {
  assert {
    condition     = var.environment != "unsupported"
    error_message = "The environment variable is set to an unsupported value."
  }
}
