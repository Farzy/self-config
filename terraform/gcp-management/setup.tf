terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.28"
    }
  }

  required_version = ">= 1.14.8"
}

provider "google" {
  project = var.project
  region  = var.region
}
