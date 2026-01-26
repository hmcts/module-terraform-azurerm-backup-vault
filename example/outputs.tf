# ---------------------------------------------------------------------------------------------------------------------
# EXAMPLE OUTPUTS
# Outputs from the example deployment showing what consumers need
# ---------------------------------------------------------------------------------------------------------------------

output "backup_vault_id" {
  description = "The ID of the Backup Vault - use this when creating backup instances"
  value       = module.backup_vault.backup_vault_id
}

output "backup_vault_principal_id" {
  description = "The Principal ID for RBAC assignments - grant this identity 'Reader' role on PostgreSQL servers"
  value       = module.backup_vault.backup_vault_principal_id
}

output "crit4_5_policy_id" {
  description = "The crit4_5 policy ID - use this for Criticality 4/5 PostgreSQL databases"
  value       = module.backup_vault.postgresql_crit4_5_policy_id
}

output "test_policy_id" {
  description = "The test policy ID - use this for testing with Plum or dev databases"
  value       = module.backup_vault.postgresql_test_policy_id
}

output "policy_ids_map" {
  description = "Map of policy names to IDs for dynamic selection"
  value       = module.backup_vault.postgresql_policy_ids
}

output "vault_configuration" {
  description = "Summary of the vault configuration"
  value       = module.backup_vault.vault_configuration
}
