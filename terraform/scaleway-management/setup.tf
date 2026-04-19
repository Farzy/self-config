terraform {
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.73"
    }
  }

  required_version = ">= 1.14.8"
}

provider "scaleway" {
  zone       = var.scaleway_zone
  region     = var.scaleway_region
  project_id = var.scaleway_project
}
