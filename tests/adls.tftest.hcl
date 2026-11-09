mock_provider "azurerm" {
  mock_resource "azurerm_data_protection_backup_vault" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.DataProtection/backupVaults/v"
      identity = { type = "SystemAssigned", principal_id = "p", tenant_id = "t", identity_ids = [] }
    }
  }
}

variables {
  name                = "bvault-test"
  resource_group_name = "rg"
}

run "defaults_unchanged" {
  command = plan
  assert {
    condition     = length(azurerm_data_protection_backup_policy_data_lake_storage.crit4_5) == 0 && length(azurerm_data_protection_backup_policy_data_lake_storage.test) == 0
    error_message = "ADLS policies must be off by default"
  }
  assert {
    condition     = length(azurerm_data_protection_backup_policy_postgresql_flexible_server.crit4_5) == 1 && length(azurerm_data_protection_backup_policy_postgresql_flexible_server.test) == 1
    error_message = "PostgreSQL policies must still be on by default"
  }
}

run "adls_enabled" {
  command = apply
  variables {
    enable_adls_crit4_5_policy = true
    enable_adls_test_policy    = true
  }
  assert {
    condition     = azurerm_data_protection_backup_policy_data_lake_storage.test[0].default_retention_duration == "P7D"
    error_message = "test policy must retain 7 days"
  }
  assert {
    condition     = azurerm_data_protection_backup_policy_data_lake_storage.crit4_5[0].default_retention_duration == azurerm_data_protection_backup_policy_postgresql_flexible_server.crit4_5[0].default_retention_rule[0].life_cycle[0].duration
    error_message = "crit4_5 default retention must match postgres"
  }
  assert {
    condition     = [for r in azurerm_data_protection_backup_policy_data_lake_storage.crit4_5[0].retention_rule : "${r.name}=${r.duration}"] == ["yearly=P1Y", "monthly=P2M", "weekly=P56D"]
    error_message = "crit4_5 rules/order must mirror postgres (yearly, monthly, weekly)"
  }
  assert {
    condition     = keys(output.adls_policy_ids) == tolist(["crit4_5", "test"]) && output.adls_test_policy_name == "adls-test"
    error_message = "outputs wrong"
  }
}

run "no_extended_retention" {
  command = plan
  variables {
    enable_adls_crit4_5_policy             = true
    crit4_5_enable_extended_retention      = false
  }
  assert {
    condition     = length(azurerm_data_protection_backup_policy_data_lake_storage.crit4_5[0].retention_rule) == 1
    error_message = "only weekly rule expected"
  }
}
