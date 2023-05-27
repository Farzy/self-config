module "scaleway-kind" {
  source = "./scaleway-kind"

  project_id = var.scaleway_project
  region = var.scaleway_region
  zone = var.scaleway_zone
}
