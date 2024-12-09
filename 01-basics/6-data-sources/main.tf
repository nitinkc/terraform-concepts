resource "local_file" "pet" {
  filename = "/tmp/hello.txt" # Use a writable directory like /tmp
  content = data.local_file.my_file.content
  # Change implementation
  file_permission = "0700"
}

data "local_file" "my_file"{
  filename = "/tmp/my_file.txt"
}