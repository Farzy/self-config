// Get LB ip ranges dynamically
data "google_compute_lb_ip_ranges" "lb-ip-ranges" {
}

// Default service account is needed in order to apply the scopes
data "google_compute_default_service_account" "default" {}
