variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "subnets" {
  description = "Map keyed by environment tag ('p'/'np'), each defining the subnet's CIDR ranges"
  type = map(object({
    primary_cidr  = string
    pods_cidr     = string
    services_cidr = string
  }))
}
