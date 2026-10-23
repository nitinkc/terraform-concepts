resource "local_file" "my_file" {
  filename = "/tmp/my_file.txt"
  content = "Test Content"
  file_permission = "0700"
}

resource "local_file" "pet" {
  filename = "/tmp/hello.txt"
  content = data.local_file.my_file.content
  file_permission = "0700"
}

# Read the source file after it is created
data "local_file" "my_file"{
  filename = local_file.my_file.filename
  # depends_on = [local_file.my_file]
}