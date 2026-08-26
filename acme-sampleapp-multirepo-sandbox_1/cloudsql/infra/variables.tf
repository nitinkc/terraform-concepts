variable "database_name" {
  type        = string
  description = "Logical database name inside the Cloud SQL instance"
  default     = "sampleapp"
}

variable "db_schema" {
  type        = string
  description = "Schema the backend's tables live in and the role that must own them"
  default     = "sa-cloud-sql"
}

variable "tier" {
  type        = string
  description = "Cloud SQL machine tier, overridden per workspace via CI/CD"
  default     = "db-custom-1-3840"
}
