locals {
  managed_domains = list("www.farzy.org", "farzy.org")
}

resource "google_compute_instance_group" "farzad-01" {
  name = "farzad-01-group"

  instances = [google_compute_instance.farzad-01.self_link]

  named_port {
    name = "http"
    port = 80
  }
  named_port {
    name = "http-81"
    port = 81
  }
  named_port {
    name = "https"
    port = 443
  }

  zone = var.zone
}

resource "google_compute_global_address" "farzy-org" {
  name         = "farzy-org-address"
  description  = "Global load-balancer adresse for website"
  address_type = "EXTERNAL"
}

resource "google_compute_ssl_policy" "tls12-restricted" {
  name            = "tls12-restricted"
  profile         = "RESTRICTED"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_global_forwarding_rule" "global-rule-https" {
  name                  = "global-rule-https"
  target                = google_compute_target_https_proxy.default.self_link
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.farzy-org.address
  port_range            = "443"
}

resource "google_compute_target_https_proxy" "default" {
  name             = "https-proxy"
  url_map          = google_compute_url_map.default.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.self_link]
  ssl_policy       = google_compute_ssl_policy.tls12-restricted.self_link
}

resource "google_compute_global_forwarding_rule" "global-rule-http" {
  name                  = "global-rule-http"
  target                = google_compute_target_http_proxy.default.self_link
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.farzy-org.address
  port_range            = "80"
}

resource "google_compute_target_http_proxy" "default" {
  name    = "https-proxy"
  url_map = google_compute_url_map.default.self_link
}

resource "random_id" "certificate" {
  byte_length = 4
  prefix      = "cert-"

  keepers = {
    domains = join(",", local.managed_domains)
  }
}

resource "google_compute_managed_ssl_certificate" "cert" {
  provider = google-beta
  name     = random_id.certificate.hex

  lifecycle {
    create_before_destroy = true
  }

  managed {
    domains = local.managed_domains
  }
}

resource "google_compute_url_map" "default" {
  name            = "url-map"
  description     = "Default URL map"
  default_service = google_compute_backend_service.default.self_link
}

resource "google_compute_backend_service" "default" {
  name        = "backend-service"
  port_name   = "http"
  protocol    = "HTTP"
  timeout_sec = 10
  health_checks = [
  google_compute_http_health_check.default.self_link]
  backend {
    group = google_compute_instance_group.farzad-01.self_link
  }
}

resource "google_compute_http_health_check" "default" {
  name               = "http-health-check"
  port               = 80
  request_path       = "/"
  check_interval_sec = 10
  timeout_sec        = 1
}
