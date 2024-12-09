variable "fileName" {
  description = "The path where the file will be created"
  type        = string
  default     = "/tmp/hello.txt"
}

variable "content" {
  description = "The content to write into the file"
  type        = string
  default     = "Hello World! Default Text"
}

variable "prefix" {
  description = "The prefix for the random pet name"
  type        = string
  default     = "Mrs"
}

variable "separator" {
  description = "The separator for the random pet name"
  type        = string
  default     = "-"
}

variable "name_length" {
  description = "The length of the random pet name"
  type        = number
  default     = 1
}
