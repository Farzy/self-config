terraform {
  required_version = ">= 1.14.8"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.28.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.28.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.8.0"
    }
  }
}
