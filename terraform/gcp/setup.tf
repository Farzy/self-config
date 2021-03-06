terraform {
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
  version     = "~> 3.21"
}

provider "google-beta" {
  credentials = file("../_auth/gcp-admin.json")
  project     = var.project
  region      = var.region
  version     = "~> 3.21"
}

provider "random" {
  version = "~> 2.2"
}
