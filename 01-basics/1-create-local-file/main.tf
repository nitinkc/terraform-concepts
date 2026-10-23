# automatic provider inference and sensible defaults
terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "> 2.9.0"
    }
  }
}

provider "local" {
  # Configuration options
}

# https://registry.terraform.io/providers/hashicorp/local/latest
resource "local_file" "pet" {
  filename = "/tmp/test.txt" # Use a writable directory like /tmp
  content  = "Sample text!!"
  # Change implementation
  file_permission = "0700" # Owner (4+2+1, RWE), Group, Others
}