output "ssh_user" {
  description = "SSH username configured on VMs"
  value       = var.ssh_user
}

output "nat_public_ip" {
  description = "Public IP of the NAT instance / jump host"
  value       = yandex_compute_instance.nat.network_interface[0].nat_ip_address
}

output "nginx_public_ip" {
  description = "Public IP of the load balancer"
  value       = yandex_compute_instance.nginx.network_interface[0].nat_ip_address
}

output "clickhouse_private_ip" {
  description = "Private IP of the ClickHouse VM"
  value       = yandex_compute_instance.clickhouse.network_interface[0].ip_address
}

output "backend_private_ips" {
  description = "Private IPs of backend VMs"
  value       = yandex_compute_instance.backends[*].network_interface[0].ip_address
}

output "service_url" {
  description = "Public URL of the service"
  value       = "http://${yandex_compute_instance.nginx.network_interface[0].nat_ip_address}"
}

output "backend_ssh_commands" {
  description = "SSH commands to connect to private backends through NAT"
  value = [
    for ip in yandex_compute_instance.backends[*].network_interface[0].ip_address :
    "ssh -J ${var.ssh_user}@${yandex_compute_instance.nat.network_interface[0].nat_ip_address} ${var.ssh_user}@${ip}"
  ]
}

output "clickhouse_ssh_command" {
  description = "SSH command to connect to ClickHouse through NAT"
  value       = "ssh -J ${var.ssh_user}@${yandex_compute_instance.nat.network_interface[0].nat_ip_address} ${var.ssh_user}@${yandex_compute_instance.clickhouse.network_interface[0].ip_address}"
}
