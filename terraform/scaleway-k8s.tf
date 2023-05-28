module "scaleway-k8s" {
  source = "./scaleway-k8s"

  project_id = var.scaleway_project
  region     = var.scaleway_region
  zone       = var.scaleway_zone
}
