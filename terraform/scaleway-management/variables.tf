variable "project_id" {
  type        = string
  description = "Scaleway project ID"
  default     = "5e40a076-f4e5-4328-8052-1a543614ec45"
}

variable "region" {
  type        = string
  description = "Scaleway region"
  default     = "fr-par"
}

variable "zone" {
  type        = string
  description = "Scaleway zone"
  default     = "fr-par-1"
}
