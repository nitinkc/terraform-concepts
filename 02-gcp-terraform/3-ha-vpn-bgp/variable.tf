variable "project" {
  description = "GCP Project ID"
  type        = string
  default     = "my-devops-journey-502420"
}

variable "region" {
  description = "GCP region for subnets, Cloud Routers, and HA VPN gateways"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for test VMs"
  type        = string
  default     = "us-central1-a"
}

variable "asn_a" {
  description = "Private BGP Autonomous System Number (ASN) for Router A (RFC 6996: 64512-65534)"
  type        = number
  default     = 65001
}

variable "asn_b" {
  description = "Private BGP Autonomous System Number (ASN) for Router B (must differ from asn_a for eBGP)"
  type        = number
  default     = 65002
}
