# Azure Backup Vault Terraform Module

Terraform module to create an Azure Data Protection Backup Vault with backup policies for PostgreSQL Flexible Server, Azure Data Lake Storage (ADLS Gen2), and Azure Blob Storage.

## Purpose

This module provisions a centralised Azure Backup Vault for Disaster Recovery (DR) protection of PostgreSQL databases, ADLS Gen2, and Azure Blob Storage. It supports vault immutability and cross-region restore for regional outage scenarios.

### Key Features

- **Vault Immutability**: Defaults to `Unlocked`; this can be changed, while `Locked` cannot be reversed
- **Geo-Redundant Storage**: Defaults to `GeoRedundant`
- **Cross-Region Restore**: Enabled by default, disabled by override whilst solely in UK South.
- **MOJ-aligned Retention**: 8-week default retention per [MOJ security guidance](https://security-guidance.service.justice.gov.uk/system-backup-standard/#retention-schedules)
- **Extended Retention**: Optional monthly and yearly point-in-time retention; defaults are 2 months and 1 year, stored in VaultStore

### Backup Policies

| Policy Name | Purpose | Default Retention | Schedule / RPO |
|-------------|---------|-------------------|----------------|
| `postgresql-crit4-5` | Criticality 4 & 5 PostgreSQL Flexible Servers | 8 weeks; weekly 8 weeks, monthly 2 months, yearly 1 year | Weekly / 7 days |
| `postgresql-test` | Testing PostgreSQL backup/restore | 7 days | Weekly / 7 days |
| `adls-crit4-5` | Criticality 4 & 5 ADLS accounts (opt-in) | Same defaults as `postgresql-crit4-5` | Weekly / 7 days |
| `adls-test` | Testing ADLS backup/restore (opt-in) | 7 days | Weekly / 7 days |
| `blob-crit4-5` | Criticality 4 & 5 Azure Blob Storage (opt-in) | 7 days OperationalStore; 8 weeks VaultStore, with weekly 8 weeks, monthly 2 months, yearly 1 year | Daily / 1 day |
| `blob-test` | Testing Azure Blob Storage backup/restore (opt-in) | 7 days in both OperationalStore and VaultStore | Daily / 1 day |

ADLS and Blob Storage policies are **disabled by default**. Enable them with `enable_adls_crit4_5_policy` / `enable_adls_test_policy` and `enable_blob_crit4_5_policy` / `enable_blob_test_policy`, respectively.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | >= 4.68.0 |

## Usage

### Basic Example

```hcl
module "backup_vault" {
  source = "git::https://github.com/hmcts/module-terraform-azurerm-backup-vault.git?ref=main"

  name                = "bvault-cpp-postgresql-prd"
  resource_group_name = azurerm_resource_group.backup.name
  location            = azurerm_resource_group.backup.location

  # Vault settings use sensible defaults:
  # - redundancy = "GeoRedundant"
  # - immutability = "Unlocked"
  # - cross_region_restore_enabled = true

  # Grant vault identity Reader on resource groups containing PostgreSQL servers
  role_assignments = {
    "reader-rg-prd-svc-01" = {
      scope                = data.azurerm_resource_group.svc.id
      role_definition_name = "Reader"
    }
  }

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

### RBAC Role Assignments

The module includes a built-in `role_assignments` variable to assign roles to the vault's managed identity on any Azure resource scope. This is required for backup enrollment of PostgreSQL Flexible Servers.

**Required roles for PostgreSQL backup:**

| Role | Scope | Managed By |
|------|-------|------------|
| `Reader` | Resource group containing the PostgreSQL server | This module (via `role_assignments`) |
| `PostgreSQL Flexible Server Long Term Retention Backup Role` | PostgreSQL server | PostgreSQL module |

```hcl
module "backup_vault" {
  source = "git::https://github.com/hmcts/module-terraform-azurerm-backup-vault.git?ref=main"

  name                = "bvault-cpp-postgresql-prd"
  resource_group_name = azurerm_resource_group.backup.name
  location            = azurerm_resource_group.backup.location

  # Grant vault identity Reader on resource groups containing PostgreSQL servers
  role_assignments = {
    "reader-rg-dev-svc-01" = {
      scope                = data.azurerm_resource_group.svc.id
      role_definition_name = "Reader"
    }
    "reader-rg-dev-data-01" = {
      scope                = data.azurerm_resource_group.data.id
      role_definition_name = "Reader"
    }
  }
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

### Azure Data Lake Storage (ADLS) Backup

```hcl
module "backup_vault" {
  source = "git::https://github.com/hmcts/module-terraform-azurerm-backup-vault.git?ref=main"
  # ...

  enable_adls_crit4_5_policy = true
  enable_adls_test_policy    = true

  # The vault identity needs "Storage Account Backup Contributor" on each storage account to be backed up
  role_assignments = {
    "backup-contributor-sadatalake01" = {
      scope                = azurerm_storage_account.datalake.id
      role_definition_name = "Storage Account Backup Contributor"
    }
  }
}

resource "azurerm_data_protection_backup_instance_data_lake_storage" "main" {
  name                            = "backup-${azurerm_storage_account.datalake.name}"
  location                        = azurerm_storage_account.datalake.location
  data_protection_backup_vault_id = module.backup_vault.backup_vault_id
  backup_policy_id                = module.backup_vault.adls_test_policy_id
  storage_account_id              = azurerm_storage_account.datalake.id
  storage_container_names         = ["container1"]
}
```

Use `adls-test` first: its 7-day retention limits how long test recovery points are retained and helps keep test backup storage costs down.

> **Note:** The ADLS policies back up on `adls_crit4_5_backup_schedule` and `adls_test_backup_schedule` (both default to daily at 02:00 UTC). Retention is shared with the PostgreSQL policies via the `crit4_5_*` and `test_*` retention variables. All arguments of the ADLS backup policy are ForceNew and Azure will not delete a policy while backup instances are attached, so changing a shared `crit4_5_*`/`test_*` value once ADLS backups exist will fail to apply for the ADLS policy.

### Azure Blob Storage Backup

Blob policies are disabled by default and use schedules independent of PostgreSQL and ADLS. The critical policy defaults to daily backups at 02:00 UTC; the test policy defaults to daily backups at 03:00 UTC. Both use a 7-day OperationalStore retention. Their VaultStore retention is 8 weeks plus the configured weekly, monthly, and yearly retention for `blob-crit4-5`, and 7 days for `blob-test`.

Enable one or both policies with `enable_blob_crit4_5_policy` and `enable_blob_test_policy`. Use the resulting `blob_crit4_5_policy_id` or `blob_test_policy_id` when creating Blob Storage backup instances.

## DR Scenarios

This module supports the following DR scenarios as defined in the initiative:

### Scenario 1: Complete Azure Region Outage
- Vault uses GeoRedundant storage with cross-region restore enabled
- In case of UK South long-term outage, Microsoft recovers the vault in the secondary GRS region
- Cross-region restore to UK West (or chosen region) can begin

### Scenario 2: Complete Azure Service Outage
- Wait for service restoration
- Restore from available recovery points once service is available

### Scenario 3: Cyber Attack
- Locked immutable backups cannot be tampered with, modified, or deleted by attackers
- Only backup and restore operations are possible
- Backups are only deleted when they expire due to retention period

## Retention Configuration

Default retention aligns with MOJ security guidance:

| Retention Type | Duration | Criteria |
|----------------|----------|----------|
| Default | 8 weeks (P56D) | All backups |
| Weekly | 8 weeks (P56D) | First backup of week |
| Monthly (Extended) | 2 months (P2M) | First backup of month |
| Yearly (Extended) | 1 year (P1Y) | First backup of year |

> **Note:** PostgreSQL Flexible Server vaulted backup stores all retention tiers in VaultStore. Archive tier storage is not supported for this workload type. Blob policies also use VaultStore for vaulted retention and additionally retain operational backups for 7 days.

Extended retention can be disabled via `crit4_5_enable_extended_retention = false`.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Backup Vault name | `string` | n/a | yes |
| resource_group_name | Resource Group name | `string` | n/a | yes |
| location | Azure region | `string` | `"uksouth"` | no |
| redundancy | Storage redundancy: `GeoRedundant`, `LocallyRedundant`, or `ZoneRedundant` | `string` | `"GeoRedundant"` | no |
| datastore_type | Data store type: `ArchiveStore`, `OperationalStore`, `SnapshotStore`, or `VaultStore` | `string` | `"VaultStore"` | no |
| cross_region_restore_enabled | Enable cross-region restore; only applies with `GeoRedundant` | `bool` | `true` | no |
| immutability | Immutability state: `Disabled`, `Locked`, or `Unlocked` | `string` | `"Unlocked"` | no |
| soft_delete | Soft-delete state: `AlwaysOn`, `Off`, or `On` | `string` | `"On"` | no |
| retention_duration_in_days | Soft-delete retention in days when `soft_delete` is `On` | `number` | `14` | no |
| enable_system_assigned_identity | Enable a system-assigned managed identity | `bool` | `true` | no |
| user_assigned_identity_ids | User-assigned managed identity resource IDs | `list(string)` | `[]` | no |
| enable_postgresql_crit4_5_policy | Create the PostgreSQL crit4_5 policy | `bool` | `true` | no |
| enable_postgresql_test_policy | Create the PostgreSQL test policy | `bool` | `true` | no |
| enable_adls_crit4_5_policy | Create the ADLS crit4_5 policy | `bool` | `false` | no |
| enable_adls_test_policy | Create the ADLS test policy | `bool` | `false` | no |
| enable_blob_crit4_5_policy | Create the Blob Storage crit4_5 policy | `bool` | `false` | no |
| enable_blob_test_policy | Create the Blob Storage test policy | `bool` | `false` | no |
| blob_crit4_5_backup_schedule | ISO 8601 schedule for Blob crit4_5 backups | `string` | Daily at 02:00 UTC | no |
| blob_test_backup_schedule | ISO 8601 schedule for Blob test backups | `string` | Daily at 03:00 UTC | no |
| crit4_5_backup_schedule | ISO 8601 schedule for PostgreSQL and ADLS crit4_5 backups | `string` | Weekly, Sunday 02:00 UTC | no |
| crit4_5_timezone | Time zone for PostgreSQL and ADLS crit4_5 schedules and Blob crit4_5 policy | `string` | `"UTC"` | no |
| crit4_5_default_retention_duration | Default crit4_5 retention duration | `string` | `"P56D"` | no |
| crit4_5_weekly_retention_duration | Weekly crit4_5 retention duration | `string` | `"P56D"` | no |
| crit4_5_monthly_retention_duration | Monthly crit4_5 retention duration | `string` | `"P2M"` | no |
| crit4_5_yearly_retention_duration | Yearly crit4_5 retention duration | `string` | `"P1Y"` | no |
| crit4_5_enable_extended_retention | Enable monthly and yearly crit4_5 retention rules | `bool` | `true` | no |
| test_backup_schedule | ISO 8601 schedule for PostgreSQL and ADLS test backups | `string` | Weekly, Sunday 03:00 UTC | no |
| test_timezone | Time zone for PostgreSQL and ADLS test schedules and Blob test policy | `string` | `"UTC"` | no |
| test_retention_duration | Test policy retention duration | `string` | `"P7D"` | no |
| role_assignments | Map of role assignments for the vault identity (`scope`, `role_definition_name`) | `map(object)` | `{}` | no |
| tags | Tags to apply to the vault | `map(string)` | `{}` | no |
| namespace | HMCTS namespace tag | `string` | `""` | no |
| costcode | Cost code tag | `string` | `""` | no |
| owner | Owner tag | `string` | `""` | no |
| application | Application tag | `string` | `""` | no |
| environment | Environment tag | `string` | `""` | no |
| type | Service type tag | `string` | `""` | no |

See [variables.tf](variables.tf) for the complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| backup_vault_id | The ID of the Backup Vault |
| backup_vault_name | The name of the Backup Vault |
| backup_vault_principal_id | The Principal ID for RBAC assignments |
| backup_vault_tenant_id | The Tenant ID of the vault's system-assigned identity |
| postgresql_crit4_5_policy_id | The crit4_5 policy ID for critical databases |
| postgresql_crit4_5_policy_name | The crit4_5 policy name |
| postgresql_test_policy_id | The test policy ID for testing |
| postgresql_test_policy_name | The test policy name |
| postgresql_policy_ids | Map of policy names to IDs |
| adls_crit4_5_policy_id | The ADLS crit4_5 policy ID (null when disabled) |
| adls_crit4_5_policy_name | The ADLS crit4_5 policy name |
| adls_test_policy_id | The ADLS test policy ID (null when disabled) |
| adls_test_policy_name | The ADLS test policy name |
| adls_policy_ids | Map of ADLS policy names to IDs |
| blob_crit4_5_policy_id | The Blob Storage crit4_5 policy ID (null when disabled) |
| blob_crit4_5_policy_name | The Blob Storage crit4_5 policy name |
| blob_test_policy_id | The Blob Storage test policy ID (null when disabled) |
| blob_test_policy_name | The Blob Storage test policy name |
| blob_policy_ids | Map of enabled Blob Storage policy names to IDs |
| role_assignment_ids | Map of role assignment keys to their Azure resource IDs |
| vault_configuration | Summary of the vault's name, location, redundancy, immutability, cross-region restore, and soft-delete settings |

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
- [Azure Data Lake Storage Backup Overview](https://learn.microsoft.com/en-gb/azure/backup/azure-data-lake-storage-backup-overview)
- [Azure Backup Authentication with PostgreSQL](https://learn.microsoft.com/en-gb/azure/backup/backup-azure-database-postgresql-flex-overview#azure-backup-authentication-with-the-postgresql-server)

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
