output "nameservers-farzy-org" {
  value = google_dns_managed_zone.farzy-org.name_servers
}
