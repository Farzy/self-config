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
  project     = var.project
  region      = var.region
}
