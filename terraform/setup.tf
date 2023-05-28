terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.77"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 3.77"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.19"
    }
  }

  required_version = ">= 1.4"

  backend "gcs" {
    bucket      = "farzad-infrastructure"
    prefix      = "terraform"
    credentials = "_auth/gcp-admin.json"
  }
}

provider "google" {
  credentials = file("_auth/gcp-admin.json")
  project     = var.google_project
  region      = var.google_region
}

provider "google-beta" {
  credentials = file("_auth/gcp-admin.json")
  project     = var.google_project
  region      = var.google_region
}

provider "scaleway" {
  zone       = var.scaleway_zone
  region     = var.scaleway_region
  project_id = var.scaleway_project
}
