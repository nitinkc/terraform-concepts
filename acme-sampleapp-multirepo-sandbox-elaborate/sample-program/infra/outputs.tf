output "vpc_network" {
  value = module.vpc.network_name
}

output "gke_clusters_created" {
  description = "Which of 'p'/'np' actually got a cluster this apply"
  value       = keys(local.gke_clusters_enabled)
}

output "dns_name_servers" {
  description = "Delegate your domain to these if you want the public zone to actually resolve"
  value       = module.dns.public_zone.name_servers
}
