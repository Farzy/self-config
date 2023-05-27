terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
      version = "~> 2.19"
    }
  }

  required_version = ">= 1.4"
}

provider "scaleway" {
  zone = var.zone
  region = var.region
  project_id = var.project_id
}
