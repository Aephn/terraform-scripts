output "vmid_range" {
  value = local.expanded_range
}

output "ip_range" {
  value = [
    for i in range(local.CIDR_host_lower, local.CIDR_host_upper, local.CIDR_host_step) :
    format("%s.%d", local.CIDR_network_ip, i)
  ]
}
