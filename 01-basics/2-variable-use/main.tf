resource "local_file" "fruits" {
  filename = var.fileName   # Ensure the directory is writable
  content  = var.content
}

# creates on console
resource "random_pet" "my_pet" {
  prefix    = var.prefix
  separator = var.separator
  length    = var.name_length
}
