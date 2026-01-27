# Azure Backup Vault Terraform Module

Terraform module to create an Azure Data Protection Backup Vault with immutable backup policies for PostgreSQL Flexible Server.

## Purpose

This module provisions a centralised Azure Backup Vault for Disaster Recovery (DR) protection of critical PostgreSQL databases. It implements immutable backups to protect against cyber attacks and supports cross-region restore for regional outage scenarios.

### Key Features

- **Immutable Backups**: Defaults to `Unlocked` immutability - backups cannot be tampered with or deleted
- **Geo-Redundant Storage**: Defaults to `GeoRedundant` for cross-region restore capability (UK South → UK West)
- **Cross-Region Restore**: Enabled by default for regional outage DR scenarios
- **MOJ Compliant Retention**: 8-week retention per [MOJ security guidance](https://security-guidance.service.justice.gov.uk/system-backup-standard/#retention-schedules)
- **Extended Retention**: Monthly and yearly point-in-time retention for long-term compliance (stored in VaultStore - archive tier not supported for PostgreSQL Flexible Server)

### Backup Policies

| Policy Name | Purpose | Default Retention | RPO |
|-------------|---------|-------------------|-----|
| `postgresql-crit4-5` | Criticality 4 & 5 services | 8 weeks + extended retention | 7 days |
| `postgresql-test` | Testing with Plum/dev DBs | 1 week | 7 days |

## Usage

### Basic Example

```hcl
module "backup_vault" {
  source = "git::https://github.com/hmcts/cpp-module-terraform-azurerm-backup-vault.git?ref=main"

  name                = "bvault-cpp-postgresql-prd"
  resource_group_name = azurerm_resource_group.backup.name
  location            = azurerm_resource_group.backup.location

  # Vault settings use sensible defaults:
  # - redundancy = "GeoRedundant"
  # - immutability = "Unlocked"
  # - cross_region_restore_enabled = true

  tags = {
    environment = "prd"
    application = "platform"
  }
}
```

### Consuming Vault Outputs in PostgreSQL Module

The vault and policy IDs are exposed as outputs for use when creating backup instances:

```hcl
# In your PostgreSQL module, create a backup instance
resource "azurerm_data_protection_backup_instance_postgresql_flexible_server" "main" {
  name                         = "backup-${azurerm_postgresql_flexible_server.main.name}"
  location                     = azurerm_postgresql_flexible_server.main.location
  vault_id                     = module.backup_vault.backup_vault_id
  backup_policy_id             = module.backup_vault.postgresql_crit4_5_policy_id
  server_id                    = azurerm_postgresql_flexible_server.main.id
}
```

### Required RBAC for PostgreSQL Backup

The backup vault's managed identity requires specific roles for backup and restore operations:

**For Backup:**
```hcl
# Long Term Retention Backup Role on the PostgreSQL server
resource "azurerm_role_assignment" "backup_ltr" {
  scope                = azurerm_postgresql_flexible_server.main.id
  role_definition_name = "PostgreSQL Flexible Server Long Term Retention Backup Role"
  principal_id         = module.backup_vault.backup_vault_principal_id
}

# Reader on the resource group containing the server
resource "azurerm_role_assignment" "backup_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = module.backup_vault.backup_vault_principal_id
}
```

**For Restore (optional - only if restoring to new server):**
```hcl
# Storage Blob Data Contributor on target storage account for restore
resource "azurerm_role_assignment" "restore_storage" {
  scope                = azurerm_storage_account.restore_target.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.backup_vault.backup_vault_principal_id
}
```

## DR Scenarios

This module supports the following DR scenarios as defined in the initiative:

### Scenario 1: Complete Azure Region Outage
- Vault uses GeoRedundant storage with cross-region restore enabled
- In case of UK South long-term outage, Microsoft recovers the vault in the secondary GRS region
- Cross-region restore to UK West (or chosen region) can begin

### Scenario 2: Complete Azure Service Outage
- Wait for service restoration
- Restore from immutable backups once service is available

### Scenario 3: Cyber Attack
- Immutable backups cannot be tampered with, modified, or deleted by attackers
- Only backup and restore operations are possible
- Backups are only deleted when they expire due to retention period

## Retention Configuration

Default retention aligns with MOJ security guidance:

| Retention Type | Duration | Criteria |
|----------------|----------|----------|
| Default | 8 weeks (P56D) | All backups |
| Weekly | 3 months (P3M) | First backup of week |
| Monthly (Extended) | 12 months (P12M) | First backup of month |
| Yearly (Extended) | 3 years (P3Y) | First backup of year |

> **Note:** PostgreSQL Flexible Server vaulted backup stores all retention tiers in VaultStore. Archive tier storage is not supported for this workload type.

Extended retention can be disabled via `crit4_5_enable_extended_retention = false`.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | The name of the Backup Vault | `string` | n/a | yes |
| resource_group_name | The name of the Resource Group | `string` | n/a | yes |
| location | The Azure Region for the Backup Vault | `string` | `"uksouth"` | no |
| redundancy | Storage redundancy (GeoRedundant, LocallyRedundant, ZoneRedundant) | `string` | `"GeoRedundant"` | no |
| immutability | Immutability state (Disabled, Locked, Unlocked) | `string` | `"Unlocked"` | no |
| cross_region_restore_enabled | Enable cross-region restore (only with GeoRedundant) | `bool` | `true` | no |
| enable_postgresql_crit4_5_policy | Create the crit4_5 backup policy | `bool` | `true` | no |
| enable_postgresql_test_policy | Create the test backup policy | `bool` | `true` | no |
| crit4_5_enable_extended_retention | Enable monthly/yearly extended retention | `bool` | `true` | no |

See [variables.tf](variables.tf) for the complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| backup_vault_id | The ID of the Backup Vault |
| backup_vault_principal_id | The Principal ID for RBAC assignments |
| postgresql_crit4_5_policy_id | The crit4_5 policy ID for critical databases |
| postgresql_test_policy_id | The test policy ID for testing |
| postgresql_policy_ids | Map of policy names to IDs |

## Important Notes

**WARNING**: Once `immutability` is set to `Locked`, it CANNOT be changed. Start with `Unlocked` until you've validated the configuration.

**WARNING**: Once `soft_delete` is set to `AlwaysOn`, it CANNOT be changed.

**WARNING**: Do not apply this to production until you've tested with the `postgresql-test` policy on non-critical databases (e.g., Plum).

## Testing

Use the `postgresql-test` policy to validate backup/restore functionality before onboarding critical databases:

1. Deploy the vault with both policies enabled
2. Create a test PostgreSQL Flexible Server (or use Plum)
3. Create a backup instance using the test policy
4. Wait for initial backup to complete
5. Test restore process
6. Document RTO (time from restore initiation to healthy DB)

## Related Links

- [DTSPO-28347 Initiative](https://tools.hmcts.net/jira/browse/DTSPO-28347)
- [MOJ Backup Retention Standards](https://security-guidance.service.justice.gov.uk/system-backup-standard/#retention-schedules)
- [Azure PostgreSQL Flexible Server Backup Support Matrix](https://learn.microsoft.com/en-gb/azure/backup/backup-azure-database-postgresql-flex-support-matrix)
- [Azure PostgreSQL Backup Tutorial](https://learn.microsoft.com/en-gb/azure/backup/tutorial-create-first-backup-azure-database-postgresql-flex)
- [Azure Backup Authentication with PostgreSQL](https://learn.microsoft.com/en-gb/azure/backup/backup-azure-database-postgresql-flex-overview#azure-backup-authentication-with-the-postgresql-server)

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
