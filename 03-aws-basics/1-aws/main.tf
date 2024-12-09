resource "aws_iam_user" "admin_user" {
  name = "lucy"

  tags = {
    Description = "Technical Team Leader"
  }
}