resource "google_dns_managed_zone" "farzy-org" {
  dns_name    = "farzy.org."
  name        = "farzy-org"
  description = "Main DNS Zone for farzy.org"
  visibility  = "public"
}

resource "google_dns_record_set" "mx" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = google_dns_managed_zone.farzy-org.dns_name
  rrdatas = [
    "10 in1-smtp.messagingengine.com.",
    "20 in2-smtp.messagingengine.com.",
  ]
  ttl  = 3600
  type = "MX"
}

resource "google_dns_record_set" "txt" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = google_dns_managed_zone.farzy-org.dns_name
  rrdatas = [
    "\"v=spf1 include:spf.messagingengine.com ?all\"",
    "google-site-verification=kbVrgpukI6ov2ahYx7_J90_PQ4VfO-zNvH63Tj8Zv3s",
  ]
  ttl  = 3600
  type = "TXT"
}

resource "google_dns_record_set" "domainkey-fm1" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = "fm1._domainkey.${google_dns_managed_zone.farzy-org.dns_name}"
  rrdatas      = ["fm1.farzy.org.dkim.fmhosted.com."]
  ttl          = 1800
  type         = "CNAME"
}

resource "google_dns_record_set" "domainkey-fm2" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = "fm2._domainkey.${google_dns_managed_zone.farzy-org.dns_name}"
  rrdatas      = ["fm2.farzy.org.dkim.fmhosted.com."]
  ttl          = 1800
  type         = "CNAME"
}

resource "google_dns_record_set" "domainkey-fm3" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = "fm3._domainkey.${google_dns_managed_zone.farzy-org.dns_name}"
  rrdatas      = ["fm3.farzy.org.dkim.fmhosted.com."]
  ttl          = 1800
  type         = "CNAME"
}

resource "google_dns_record_set" "txt-keybase" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = "_keybase.${google_dns_managed_zone.farzy-org.dns_name}"
  rrdatas = [
    "\"keybase-site-verification=O0WZdKzTjk5kCNutB7oJCsusrPH1ousPZ7UBOJN6UIc\"",
  ]
  ttl  = 10800
  type = "TXT"
}

resource "google_dns_record_set" "comodoca" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = "1DD8F84CE7D1701062F3375DC90414E3.www.${google_dns_managed_zone.farzy-org.dns_name}"
  rrdatas      = ["930F706B41145B8F94E4F484EBEA46595CD2C01D.comodoca.com."]
  ttl          = 10800
  type         = "CNAME"
}

resource "google_dns_record_set" "quassel" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = "quassel.${google_dns_managed_zone.farzy-org.dns_name}"
  rrdatas      = ["51.15.247.70"]
  ttl          = 3600
  type         = "A"
}

resource "google_dns_record_set" "farzad-01" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = "farzad-01.${google_dns_managed_zone.farzy-org.dns_name}"
  rrdatas      = [google_compute_address.farzad-01-address.address]
  ttl          = 3600
  type         = "A"
}

resource "google_dns_record_set" "root-a" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = google_dns_managed_zone.farzy-org.dns_name
  rrdatas      = [google_compute_global_address.farzy-org.address]
  ttl          = 3600
  type         = "A"
}

resource "google_dns_record_set" "www" {
  managed_zone = google_dns_managed_zone.farzy-org.name
  name         = "www.${google_dns_managed_zone.farzy-org.dns_name}"
  rrdatas      = [google_compute_global_address.farzy-org.address]
  ttl          = 3600
  type         = "A"
}

