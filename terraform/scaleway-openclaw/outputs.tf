output "public_ip" {
  value = scaleway_instance_ip.openclaw_ip.address
}

output "instance_id" {
  value = scaleway_instance_server.openclaw_server.id
}
