resource "google_compute_address" "farzad-01-address-internal" {
  name         = "farzad-01-address-internal"
  region       = var.region
  subnetwork   = google_compute_subnetwork.production-subnetwork-europe-west1.self_link
  address_type = "INTERNAL"
}

resource "google_compute_address" "farzad-01-address" {
  name         = "farzad-01-address"
  region       = var.region
  address_type = "EXTERNAL"
}

resource "google_compute_disk" "farzad-01-system" {

  name = "farzad-01"
  zone = var.zone

  type  = "pd-standard"
  size  = "20"
  image = "debian-cloud/debian-10" // Use latest Debian 10 image

  labels = {
    env = "prod"
  }
}

resource "google_compute_instance" "farzad-01" {
  name         = "farzad-01"
  zone         = var.zone
  machine_type = "e2-micro"

  tags = ["env-prod"]

  boot_disk {
    source      = google_compute_disk.farzad-01-system.self_link
    device_name = google_compute_disk.farzad-01-system.name
    auto_delete = false
  }

  network_interface {
    subnetwork = google_compute_subnetwork.production-subnetwork-europe-west1.self_link
    network_ip = google_compute_address.farzad-01-address-internal.address

    access_config {
      nat_ip = google_compute_address.farzad-01-address.address
    }
  }

  labels = {
    env = "prod"
  }

  service_account {
    email = data.google_compute_default_service_account.default.email

    // When defining a specific service account, the privileges are already
    // restricted and we don't need to use scopes.
    // cloud-platform scope gives full access to all Cloud APIs.
    scopes = var.service_account_scopes
  }

  allow_stopping_for_update = true

  lifecycle {
    prevent_destroy = true
  }

  scheduling {
    automatic_restart = true
  }
}
