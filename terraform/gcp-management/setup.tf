provider "google" {
  credentials = file("../_auth/gcp-admin.json")
  project     = var.project
  region      = var.region
  version     = "~> 3.21"
}
