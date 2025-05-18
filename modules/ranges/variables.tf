
locals {
  expanded_range = [
    for i in range(7500, 7505, 1) : i
  ]

  CIDR_host_lower = 0 //< Specify upper host number range
  CIDR_host_upper = 5 //< Specify lower host number range
  CIDR_host_step  = 1 //< Specify step in ip range
  CIDR_network_ip = "192.168.10"
}

