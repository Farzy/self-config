resource "google_compute_firewall" "production-default-allow-icmp" {
  name    = "default-allow-icmp"
  network = google_compute_network.production.name

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "production-default-allow-internal" {
  name    = "default-allow-internal"
  network = google_compute_network.production.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [google_compute_subnetwork.production-subnetwork-europe-west1.ip_cidr_range]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "production-default-allow-ssh" {
  name    = "default-allow-ssh"
  network = google_compute_network.production.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "production-allow-traffic-from-lb" {
  name    = "${google_compute_network.production.name}-allow-traffic-from-lb"
  network = google_compute_network.production.name

  allow {
    protocol = "tcp"
  }

  source_ranges = data.google_compute_lb_ip_ranges.lb-ip-ranges.http_ssl_tcp_internal
}
