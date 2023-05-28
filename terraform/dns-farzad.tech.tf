resource "google_dns_managed_zone" "farzad-tech" {
  dns_name    = "farzad.tech."
  name        = "farzad-tech"
  description = "Main DNS Zone for farzad-tect"
  visibility  = "public"
}

resource "google_dns_record_set" "kind-server" {
  managed_zone = google_dns_managed_zone.farzad-tech.name
  name         = "kind.${google_dns_managed_zone.farzad-tech.dns_name}"
  rrdatas      = [module.scaleway-kind.kind-ip]
  ttl          = 600
  type         = "A"
}
