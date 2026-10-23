resource "local_file" "pet" {
  filename = var.fileName   # Ensure the directory is writable

  #Id is the attribute of the resource of my_pet
  content  = "Here is the Random Pet ${random_pet.my_pet.id} - ${random_pet.my_pet.prefix}"
}

# For Random Pet - https://registry.terraform.io/providers/hashicorp/random/3.9.0/docs/resources/pet
resource "random_pet" "my_pet" {
  prefix    = var.prefix
  separator = var.separator
  length    = var.name_length
}
