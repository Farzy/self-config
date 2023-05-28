resource "google_dns_managed_zone" "farzad-tech" {
  dns_name    = "farzad.tech."
  name        = "farzad-tech"
  description = "Main DNS Zone for farzad-tect"
  visibility  = "public"
}

resource "google_dns_record_set" "k8s-server" {
  managed_zone = google_dns_managed_zone.farzad-tech.name
  name         = "k8s.${google_dns_managed_zone.farzad-tech.dns_name}"
  rrdatas      = [module.scaleway-k8s.k8s-ip]
  ttl          = 600
  type         = "A"
}
