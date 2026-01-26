# ---------------------------------------------------------------------------------------------------------------------
# EXAMPLE VARIABLES
# Variables for the example deployment
# ---------------------------------------------------------------------------------------------------------------------

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
  default     = "rg-backup-vault-test"
}

variable "location" {
  type        = string
  description = "The Azure region for resources"
  default     = "uksouth"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., dev, stg, prd)"
  default     = "dev"
}

variable "namespace" {
  type        = string
  description = "Namespace for tagging"
  default     = "cpp"
}

variable "application" {
  type        = string
  description = "Application name for tagging"
  default     = "platform"
}

variable "owner" {
  type        = string
  description = "Owner for tagging"
  default     = "platops"
}

variable "costcode" {
  type        = string
  description = "Cost code for tagging"
  default     = ""
}
