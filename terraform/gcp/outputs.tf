output "nameservers-farzy-org" {
  value = google_dns_managed_zone.farzy-org.name_servers
}

output "nameservers-farz-ad" {
  value = google_dns_managed_zone.farz-ad.name_servers
}
