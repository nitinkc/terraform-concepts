resource "local_file" "pet" {
  filename = "/tmp/hello.txt" # Use a writable directory like /tmp
  content = "Hello! Let the learning commence...."
  # Change implementation
  file_permission = "0700"

  lifecycle {
    # create_before_destroy = true
    # prevent_destroy = true
    # ignore_changes = all
    ignore_changes = [
      tags
    ]
  }
}