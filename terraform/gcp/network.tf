resource "google_compute_network" "production" {
  name                    = var.production_network_name
  auto_create_subnetworks = "false"
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "production-subnetwork-europe-west1" {
  name    = var.production_network_name
  network = google_compute_network.production.self_link

  ip_cidr_range = "10.42.0.0/20"

  region                   = "europe-west1"
  private_ip_google_access = true
}

resource "google_compute_router" "production" {
  name    = "router-${var.production_network_name}"
  network = google_compute_network.production.self_link
  region  = var.region

  bgp {
    asn            = 4205000001
    advertise_mode = "DEFAULT"
  }
}

resource "google_compute_router_nat" "production-nat" {
  name                               = "nat-${var.production_network_name}"
  router                             = google_compute_router.production.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
