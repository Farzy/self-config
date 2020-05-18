resource "google_compute_firewall" "production-default-allow-icmp" {
  name    = "default-allow-icmp"
  network = google_compute_network.production.name

  allow {
    protocol = "icmp"
  }

  source_ranges = [ "0.0.0.0/0" ]

  enable_logging = true
}

resource "google_compute_firewall" "production-default-allow-internal" {
  name    = "default-allow-internal"
  network = google_compute_network.production.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports = [ "0-65535" ]
  }

  allow {
    protocol = "udp"
    ports = [ "0-65535" ]
  }

  source_ranges = [ google_compute_subnetwork.production-subnetwork-europe-west1.ip_cidr_range ]

  enable_logging = true
}

resource "google_compute_firewall" "production-default-allow-ssf" {
  name    = "default-allow-ssh"
  network = google_compute_network.production.name

  allow {
    protocol = "tcp"
    ports = [ "22" ]
  }

  source_ranges = [ "0.0.0.0/0" ]

  enable_logging = true
}
