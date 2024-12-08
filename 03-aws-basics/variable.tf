variable "ami" {
  description = "The AMI ID to use for the instance"
  type        = string
  default     = "ami 0edab43b6fa892279"  # Replace with a valid AMI ID
}

variable "instance_type" {
  description = "The instance type to use"
  type        = string
  default     = "t2.micro"
}
