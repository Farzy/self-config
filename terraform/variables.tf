variable "google_project" {
  default = "macro-raceway-277610"
}

variable "google_region" {
  default = "europe-west1"
}

variable "google_zone" {
  default = "europe-west1-b"
}

variable "scaleway_project" {
  type = string
  description = "Scaleway project ID"
  default = "5e40a076-f4e5-4328-8052-1a543614ec45"
}

variable "scaleway_region" {
  type = string
  description = "Scaleway region"
  default = "fr-par"
}

variable "scaleway_zone" {
  type = string
  description = "Scaleway zone"
  default = "fr-par-1"
}
