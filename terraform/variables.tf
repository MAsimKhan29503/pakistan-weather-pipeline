variable "location" {
  description = "Azure region for the infrastructure"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group containing the weather data platform"
  type        = string
  default     = "rg_internship_project"
}