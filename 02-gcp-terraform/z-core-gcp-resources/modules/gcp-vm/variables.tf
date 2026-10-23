variable "instance_name" {
  type        = string
  description = "Name of the compute instance"
}

variable "machine_type" {
  type        = string
  description = "GCP machine type"
  default     = "e2-medium"

  # Enterprise FDE safeguard: Precondition validation
  validation {
    condition     = can(regex("^(e2-|n1-|n2-)", var.machine_type))
    error_message = "Machine type must start with e2-, n1-, or n2- for cost compliance."
  }
}

variable "zone" {
  type        = string
  description = "GCP zone"
}

variable "subnetwork_id" {
  type        = string
  description = "Self link or ID of the subnetwork"
}