# Field name matches local.program_gcp.dns.public_zone.dns_name, read by
# backend/infra/main.tf when building local.frontend_host_name.

output "public_zone" {
  value = {
    dns_name     = google_dns_managed_zone.public.dns_name
    name_servers = google_dns_managed_zone.public.name_servers
  }
}
