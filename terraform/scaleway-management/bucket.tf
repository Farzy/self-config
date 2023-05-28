resource "scaleway_object_bucket" "scaleway-management" {
  name = "scaleway-management"
  versioning {
    enabled = true
  }
}
