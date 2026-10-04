variable "project_id" {
  type        = string
  description = "Scaleway project ID"
}

variable "instance_type" {
  type        = string
  description = "Scaleway instance type"
  # PRO2-XXS (2 dedicated vCPU / 8 GiB): PLAY2-NANO (4 GiB) was memory-starved.
  # PLAY2-MICRO (4 vCPU / 8 GiB) is an equivalent alternative when in stock in fr-par-1.
  default = "PRO2-XXS"
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
