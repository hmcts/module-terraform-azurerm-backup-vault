terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
  default     = null
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
