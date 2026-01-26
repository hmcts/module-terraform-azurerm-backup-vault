# ---------------------------------------------------------------------------------------------------------------------
# AZURE BACKUP VAULT
# Creates an Azure Data Protection Backup Vault with immutable backup support
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_data_protection_backup_vault" "main" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  datastore_type      = var.datastore_type
  redundancy          = var.redundancy

  # Cross-region restore only works with GeoRedundant storage
  cross_region_restore_enabled = var.redundancy == "GeoRedundant" ? var.cross_region_restore_enabled : false

  # Immutability settings - default to Unlocked for immutable backups
  immutability = var.immutability

  # Soft delete settings
  soft_delete                = var.soft_delete
  retention_duration_in_days = var.soft_delete == "On" ? var.retention_duration_in_days : null

  # Identity block for SystemAssigned and/or UserAssigned managed identity
  dynamic "identity" {
    for_each = var.enable_system_assigned_identity || length(var.user_assigned_identity_ids) > 0 ? [1] : []
    content {
      type = local.identity_type
      identity_ids = length(var.user_assigned_identity_ids) > 0 ? var.user_assigned_identity_ids : null
    }
  }

  tags = merge(var.tags, local.common_tags)

  lifecycle {
    # Prevent accidental destruction of immutable vault
    prevent_destroy = false
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# BACKUP POLICY - CRIT4_5 (Criticality 4 and 5 Services)
# Policy for critical services with 8-week retention per MOJ security guidance
# Reference: https://security-guidance.service.justice.gov.uk/system-backup-standard/#retention-schedules
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_data_protection_backup_policy_postgresql_flexible_server" "crit4_5" {
  count = var.enable_postgresql_crit4_5_policy ? 1 : 0

  name     = "postgresql-crit4-5"
  vault_id = azurerm_data_protection_backup_vault.main.id

  # Weekly backup schedule (RPO of 7 days as per initiative)
  backup_repeating_time_intervals = [var.crit4_5_backup_schedule]
  time_zone                       = var.crit4_5_timezone

  # Default retention - 8 weeks per MOJ security guidance for high impact services
  default_retention_rule {
    life_cycle {
      duration        = var.crit4_5_default_retention_duration
      data_store_type = "VaultStore"
    }
  }

  # Weekly retention - keep first backup of each week for 3 months
  retention_rule {
    name     = "weekly"
    priority = 20

    life_cycle {
      duration        = var.crit4_5_weekly_retention_duration
      data_store_type = "VaultStore"
    }

    criteria {
      absolute_criteria = "FirstOfWeek"
    }
  }

  # Monthly retention - keep first backup of each month for 12 months (VaultStore long-term retention)
  dynamic "retention_rule" {
    for_each = var.crit4_5_enable_extended_retention ? [1] : []
    content {
      name     = "monthly"
      priority = 15

      life_cycle {
        duration        = var.crit4_5_monthly_retention_duration
        data_store_type = "VaultStore"
      }

      criteria {
        absolute_criteria = "FirstOfMonth"
      }
    }
  }

  # Yearly retention - keep first backup of each year for 3 years (VaultStore long-term retention)
  dynamic "retention_rule" {
    for_each = var.crit4_5_enable_extended_retention ? [1] : []
    content {
      name     = "yearly"
      priority = 10

      life_cycle {
        duration        = var.crit4_5_yearly_retention_duration
        data_store_type = "VaultStore"
      }

      criteria {
        absolute_criteria = "FirstOfYear"
      }
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# BACKUP POLICY - TEST
# Minimal retention policy for testing backup functionality with Plum or other test databases
# This allows validation of backup/restore processes at minimal cost
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_data_protection_backup_policy_postgresql_flexible_server" "test" {
  count = var.enable_postgresql_test_policy ? 1 : 0

  name     = "postgresql-test"
  vault_id = azurerm_data_protection_backup_vault.main.id

  # Weekly backup schedule
  backup_repeating_time_intervals = [var.test_backup_schedule]
  time_zone                       = var.test_timezone

  # Minimal retention - 1 week for testing purposes
  default_retention_rule {
    life_cycle {
      duration        = var.test_retention_duration
      data_store_type = "VaultStore"
    }
  }
}
