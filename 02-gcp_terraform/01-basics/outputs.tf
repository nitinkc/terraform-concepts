
output "service_account" {
  description = "Google service account (with workload identity) for the backend application."
  value = {
    id    = google_service_account.gsa.account_id
    email = google_service_account.gsa.email
  }
}

# "type": "constraints/iam.disableServiceAccountKeyCreation"
# output "service_account_private_key" {
#   description = "The private key for the service account."
#   value       = google_service_account_key.my-key.private_key
#   sensitive   = true # This prevents the value from being printed in CLI outputs
# }
