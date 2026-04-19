variable "project" {
  type    = string
  default = "macro-raceway-277610"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "production_network_name" {
  type    = string
  default = "production-network"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "service_account_scopes" {
  description = "Service account scopes"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/trace.append",
  ]
}
