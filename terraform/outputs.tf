output "nameservers-farzad-tech" {
  value = google_dns_managed_zone.farzad-tech.name_servers
}

output "nameservers-farzy-org" {
  value = module.gcp.nameservers-farzy-org
}
