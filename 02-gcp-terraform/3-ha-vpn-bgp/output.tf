output "vm_a_ip" {
  description = "Internal IP of VM A in vpn-vpc-a (10.10.0.0/24)"
  value       = google_compute_instance.vm_a.network_interface[0].network_ip
}

output "vm_b_ip" {
  description = "Internal IP of VM B in vpn-vpc-b (10.20.0.0/24)"
  value       = google_compute_instance.vm_b.network_interface[0].network_ip
}

output "gateway_a_interfaces" {
  description = "The two auto-allocated external public IPs on HA VPN Gateway A (Interface 0 & Interface 1)"
  value       = google_compute_ha_vpn_gateway.ha_gateway_a.vpn_interfaces
}

output "gateway_b_interfaces" {
  description = "The two auto-allocated external public IPs on HA VPN Gateway B (Interface 0 & Interface 1)"
  value       = google_compute_ha_vpn_gateway.ha_gateway_b.vpn_interfaces
}

output "bgp_session_summary" {
  description = "BGP peering topology across the two active/active HA VPN tunnel pairs"
  value = {
    tunnel_0 = {
      router_a_asn = var.asn_a
      router_a_ip  = google_compute_router_interface.router_a_if0.ip_range
      router_b_asn = var.asn_b
      router_b_ip  = google_compute_router_interface.router_b_if0.ip_range
    }
    tunnel_1 = {
      router_a_asn = var.asn_a
      router_a_ip  = google_compute_router_interface.router_a_if1.ip_range
      router_b_asn = var.asn_b
      router_b_ip  = google_compute_router_interface.router_b_if1.ip_range
    }
  }
}
