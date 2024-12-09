resource "local_file" "pet" {
  filename = var.fileName   # Ensure the directory is writable

  #Id is the attribute of the resource of my_pet
  content  = "Here is the Random Pet ${random_pet.my_pet.id}"
}

resource "random_pet" "my_pet" {
  prefix    = var.prefix
  separator = var.separator
  length    = var.name_length
}
