resource "local_file" "fruits" {
  filename = var.fileName   # Ensure the directory is writable
  content  = var.content
}

# https://registry.terraform.io/providers/hashicorp/random/3.9.0/docs/resources/pet
resource "random_pet" "my_pet" {
  prefix    = var.prefix
  separator = var.separator
  length    = var.name_length
}


resource "local_file" "computed" {
  filename = "${local.base_dir}/greeting-${local.timestamp_suffix}.txt"
  content  = local.full_greeting
}
