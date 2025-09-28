resource "google_dns_managed_zone" "farzad-tech" {
  dns_name    = "farzad.tech."
  name        = "farzad-tech"
  description = "Main DNS Zone for farzad-tect"
  visibility  = "public"

  dnssec_config {
    state = "on"
  }
}

resource "google_dns_record_set" "k8s-server" {
  managed_zone = google_dns_managed_zone.farzad-tech.name
  name         = "k8s.${google_dns_managed_zone.farzad-tech.dns_name}"
  rrdatas      = [module.scaleway-k8s.k8s-ip]
  ttl          = var.dns_ttl_medium
  type         = "A"
}

resource "google_dns_record_set" "argocd" {
  managed_zone = google_dns_managed_zone.farzad-tech.name
  name         = "fargo.${google_dns_managed_zone.farzad-tech.dns_name}"
  rrdatas      = [google_dns_record_set.k8s-server.name]
  ttl          = var.dns_ttl_medium
  type         = "CNAME"
}

resource "google_dns_record_set" "argocdgrpc" {
  managed_zone = google_dns_managed_zone.farzad-tech.name
  name         = "fargo-grpc.${google_dns_managed_zone.farzad-tech.dns_name}"
  rrdatas      = [google_dns_record_set.k8s-server.name]
  ttl          = var.dns_ttl_medium
  type         = "CNAME"
}

resource "google_dns_record_set" "grafana" {
  managed_zone = google_dns_managed_zone.farzad-tech.name
  name         = "fargo-grafana.${google_dns_managed_zone.farzad-tech.dns_name}"
  rrdatas      = [google_dns_record_set.k8s-server.name]
  ttl          = var.dns_ttl_medium
  type         = "CNAME"
}

resource "google_dns_record_set" "minecraft-01" {
  managed_zone = google_dns_managed_zone.farzad-tech.name
  name         = "minecraft-01.${google_dns_managed_zone.farzad-tech.dns_name}"
  rrdatas      = ["51.15.200.177"]
  ttl          = var.dns_ttl_medium
  type         = "A"
}

resource "google_dns_record_set" "minecraft-01-srv" {
  managed_zone = google_dns_managed_zone.farzad-tech.name
  name         = "_minecraft._tcp.minecraft-01.${google_dns_managed_zone.farzad-tech.dns_name}"
  rrdatas      = ["0 5 25565 ${google_dns_record_set.minecraft-01.name}"]
  ttl          = var.dns_ttl_medium
  type         = "SRV"
}

resource "google_dns_record_set" "minecraft-02-srv" {
  managed_zone = google_dns_managed_zone.farzad-tech.name
  name         = "_minecraft._tcp.minecraft-02.${google_dns_managed_zone.farzad-tech.dns_name}"
  rrdatas      = ["0 5 25566 ${google_dns_record_set.minecraft-01.name}"]
  ttl          = var.dns_ttl_medium
  type         = "SRV"
}
