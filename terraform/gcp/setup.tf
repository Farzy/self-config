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
  }

  required_version = ">= 0.13"

  backend "gcs" {
    bucket      = "farzad-infrastructure"
    prefix      = "gcp"
    credentials = "../_auth/gcp-admin.json"
  }
}

provider "google" {
  credentials = file("../_auth/gcp-admin.json")
  project     = var.project
  region      = var.region
}

provider "google-beta" {
  credentials = file("../_auth/gcp-admin.json")
  project     = var.project
  region      = var.region
}

