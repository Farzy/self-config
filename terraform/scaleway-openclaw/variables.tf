variable "project_id" {
  type        = string
  description = "Scaleway project ID"
}

variable "instance_type" {
  type        = string
  description = "Scaleway instance type"
  default     = "PRO2-XXS"
}

variable "instance_name" {
  type        = string
  description = "Scaleway instance name"
  default     = "openclaw"
}

variable "image" {
  type        = string
  description = "Scaleway instance image ID"
  default     = "debian_bookworm"
}
