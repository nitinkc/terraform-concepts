terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "> 2.4.1"
    }
  }
}

provider "local" {
  # Configuration options
}

resource "local_file" "pet" {
  filename = "hello.txt" # Use a writable directory like /tmp
  content = "My test file!!"
  file_permission = "0700"
}