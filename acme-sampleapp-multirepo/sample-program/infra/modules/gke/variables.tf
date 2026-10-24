variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

variable "name" {
  type = string
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "machine_type" {
  type    = string
  default = "e2-small"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "spot" {
  type    = bool
  default = true
}
