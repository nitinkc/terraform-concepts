locals {
  timestamp_suffix = formatdate("YYYYMMDD", timestamp())
  base_dir         = "/tmp/tf-practice-locals"
  # Resource Attribute
  full_greeting    = "Hello from ${random_pet.my_pet.id}! Generated on ${local.timestamp_suffix}."
}