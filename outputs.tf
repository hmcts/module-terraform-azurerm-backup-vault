# ---------------------------------------------------------------------------------------------------------------------
# BACKUP VAULT OUTPUTS
# Outputs for consumers (e.g., PostgreSQL modules) to reference when creating backup instances
# ---------------------------------------------------------------------------------------------------------------------

output "backup_vault_id" {
  description = "The ID of the Azure Backup Vault. Use this when creating backup instances in consumer modules."
  value       = azurerm_data_protection_backup_vault.main.id
}

output "backup_vault_name" {
  description = "The name of the Azure Backup Vault."
  value       = azurerm_data_protection_backup_vault.main.name
}

output "backup_vault_principal_id" {
  description = "The Principal ID of the SystemAssigned Managed Identity for the Backup Vault. Use this for RBAC assignments to allow the vault to backup PostgreSQL instances."
  value       = try(azurerm_data_protection_backup_vault.main.identity[0].principal_id, null)
}

output "backup_vault_tenant_id" {
  description = "The Tenant ID of the SystemAssigned Managed Identity for the Backup Vault."
  value       = try(azurerm_data_protection_backup_vault.main.identity[0].tenant_id, null)
}

# ---------------------------------------------------------------------------------------------------------------------
# BACKUP POLICY OUTPUTS
# Policy IDs for use when creating backup instances
# ---------------------------------------------------------------------------------------------------------------------

output "postgresql_crit4_5_policy_id" {
  description = "The ID of the crit4_5 backup policy for PostgreSQL Flexible Server. Use this policy ID when onboarding criticality 4 or 5 databases to the backup vault."
  value       = var.enable_postgresql_crit4_5_policy ? azurerm_data_protection_backup_policy_postgresql_flexible_server.crit4_5[0].id : null
}

output "postgresql_crit4_5_policy_name" {
  description = "The name of the crit4_5 backup policy for PostgreSQL Flexible Server."
  value       = var.enable_postgresql_crit4_5_policy ? azurerm_data_protection_backup_policy_postgresql_flexible_server.crit4_5[0].name : null
}

output "postgresql_test_policy_id" {
  description = "The ID of the test backup policy for PostgreSQL Flexible Server. Use this policy ID when testing backup functionality with non-production databases."
  value       = var.enable_postgresql_test_policy ? azurerm_data_protection_backup_policy_postgresql_flexible_server.test[0].id : null
}

output "postgresql_test_policy_name" {
  description = "The name of the test backup policy for PostgreSQL Flexible Server."
  value       = var.enable_postgresql_test_policy ? azurerm_data_protection_backup_policy_postgresql_flexible_server.test[0].name : null
}

# ---------------------------------------------------------------------------------------------------------------------
# CONVENIENCE OUTPUTS
# Map outputs for easy consumption
# ---------------------------------------------------------------------------------------------------------------------

output "postgresql_policy_ids" {
  description = "Map of all PostgreSQL backup policy names to their IDs. Use this for dynamic policy selection based on criticality."
  value = merge(
    var.enable_postgresql_crit4_5_policy ? {
      "crit4_5" = azurerm_data_protection_backup_policy_postgresql_flexible_server.crit4_5[0].id
    } : {},
    var.enable_postgresql_test_policy ? {
      "test" = azurerm_data_protection_backup_policy_postgresql_flexible_server.test[0].id
    } : {}
  )
}

output "vault_configuration" {
  description = "Summary of the backup vault configuration for documentation and validation purposes."
  value = {
    name                         = azurerm_data_protection_backup_vault.main.name
    location                     = azurerm_data_protection_backup_vault.main.location
    redundancy                   = var.redundancy
    immutability                 = var.immutability
    cross_region_restore_enabled = var.redundancy == "GeoRedundant" ? var.cross_region_restore_enabled : false
    soft_delete                  = var.soft_delete
  }
}
