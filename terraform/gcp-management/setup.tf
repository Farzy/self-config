terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.77"
    }
  }

  required_version = ">= 1.0"
}

provider "google" {
  credentials = file("../_auth/gcp-admin.json")
  project     = var.project
  region      = var.region
}
