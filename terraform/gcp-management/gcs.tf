resource "google_storage_bucket" "farzad-infrastructure" {
  name          = "farzad-infrastructure"
  location      = "EU"
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}
