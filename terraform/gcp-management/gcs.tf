resource "google_storage_bucket" "farzad-infrastructure" {
  name          = "farzad-infrastructure"
  location      = "EU"
  force_destroy = false

  bucket_policy_only = false

  versioning {
    enabled = true
  }
}
