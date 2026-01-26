# ---------------------------------------------------------------------------------------------------------------------
# EXAMPLE: Azure Backup Vault for PostgreSQL Immutable Backups
# This example demonstrates how to create a centralised backup vault with immutable backup policies
# for Criticality 4/5 PostgreSQL Flexible Server databases.
#
# Use Case:
# - DR protection for critical PostgreSQL databases
# - Immutable backups protected from cyber attacks
# - Cross-region restore capability (UK South -> UK West)
# - 8-week retention per MOJ security guidance
# ---------------------------------------------------------------------------------------------------------------------

# Create a resource group for the backup vault
resource "azurerm_resource_group" "backup" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    environment = var.environment
    application = var.application
    owner       = var.owner
    costcode    = var.costcode
  }
}

# Create the centralised backup vault with immutable backup policies
module "backup_vault" {
  source = "../"

  name                = "bvault-${var.namespace}-postgresql-${var.environment}"
  resource_group_name = azurerm_resource_group.backup.name
  location            = azurerm_resource_group.backup.location

  # Vault settings - defaults are already set for immutable, geo-redundant storage
  # Uncomment to override defaults:
  # redundancy                   = "GeoRedundant"    # Default - enables cross-region restore
  # cross_region_restore_enabled = true              # Default - for UK South -> UK West DR scenario
  # immutability                 = "Unlocked"        # Default - immutable but can be configured
  # soft_delete                  = "On"              # Default - protects against accidental deletion

  # Enable both policies - crit4_5 for production, test for validation
  enable_postgresql_crit4_5_policy = true
  enable_postgresql_test_policy    = true

  # crit4_5 policy uses sensible defaults per initiative:
  # - Weekly backups (RPO: 7 days)
  # - 8-week default retention (per MOJ security guidance)
  # - 3-month weekly retention
  # - 12-month monthly archive retention
  # - 3-year yearly archive retention

  # Tags
  namespace   = var.namespace
  application = var.application
  environment = var.environment
  owner       = var.owner
  costcode    = var.costcode

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "Immutable PostgreSQL backups for DR"
  }
}
