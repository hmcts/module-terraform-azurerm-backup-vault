# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# These variables must be set when using this module.
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  type        = string
  description = "The name of the Backup Vault. Changing this forces a new resource to be created."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the Resource Group where the Backup Vault should exist."
}

variable "location" {
  type        = string
  description = "The Azure Region where the Backup Vault should exist."
  default     = "uksouth"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Vault Configuration
# These variables have reasonable defaults but can be overridden.
# ---------------------------------------------------------------------------------------------------------------------

variable "redundancy" {
  type        = string
  description = "Specifies the backup storage redundancy. Possible values are GeoRedundant, LocallyRedundant and ZoneRedundant. Defaults to GeoRedundant for cross-region restore capability."
  default     = "GeoRedundant"

  validation {
    condition     = contains(["GeoRedundant", "LocallyRedundant", "ZoneRedundant"], var.redundancy)
    error_message = "redundancy must be one of: GeoRedundant, LocallyRedundant, ZoneRedundant."
  }
}

variable "datastore_type" {
  type        = string
  description = "Specifies the type of the data store. Possible values are ArchiveStore, OperationalStore, SnapshotStore and VaultStore."
  default     = "VaultStore"

  validation {
    condition     = contains(["ArchiveStore", "OperationalStore", "SnapshotStore", "VaultStore"], var.datastore_type)
    error_message = "datastore_type must be one of: ArchiveStore, OperationalStore, SnapshotStore, VaultStore."
  }
}

variable "cross_region_restore_enabled" {
  type        = bool
  description = "Whether to enable cross-region restore for the Backup Vault. Only applicable when redundancy is GeoRedundant. Once enabled, it cannot be disabled."
  default     = true
}

variable "immutability" {
  type        = string
  description = "The state of immutability for this Backup Vault. Possible values are Disabled, Locked, and Unlocked. Defaults to Unlocked for immutable backups that can be configured but not tampered with. WARNING: Locked cannot be changed once set."
  default     = "Unlocked"

  validation {
    condition     = contains(["Disabled", "Locked", "Unlocked"], var.immutability)
    error_message = "immutability must be one of: Disabled, Locked, Unlocked."
  }
}

variable "soft_delete" {
  type        = string
  description = "The state of soft delete for this Backup Vault. Possible values are AlwaysOn, Off, and On. Defaults to On. WARNING: AlwaysOn cannot be changed once set."
  default     = "On"

  validation {
    condition     = contains(["AlwaysOn", "Off", "On"], var.soft_delete)
    error_message = "soft_delete must be one of: AlwaysOn, Off, On."
  }
}

variable "retention_duration_in_days" {
  type        = number
  description = "The soft delete retention duration for this Backup Vault. Possible values are between 14 and 180. Defaults to 14. Required when soft_delete is On."
  default     = 14

  validation {
    condition     = var.retention_duration_in_days >= 14 && var.retention_duration_in_days <= 180
    error_message = "retention_duration_in_days must be between 14 and 180."
  }
}

variable "enable_system_assigned_identity" {
  type        = bool
  description = "Whether to enable a SystemAssigned Managed Identity for this Backup Vault. Required for backing up PostgreSQL Flexible Servers."
  default     = true
}

variable "user_assigned_identity_ids" {
  type        = list(string)
  description = "A list of User Assigned Managed Identity IDs to be assigned to this Backup Vault."
  default     = []
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Backup Policies
# Feature flags to enable/disable specific backup policies
# ---------------------------------------------------------------------------------------------------------------------

variable "enable_postgresql_crit4_5_policy" {
  type        = bool
  description = "Whether to create the crit4_5 backup policy for PostgreSQL Flexible Server. This policy is for Criticality 4 and 5 services with 8-week retention and extended long-term retention."
  default     = true
}

variable "enable_postgresql_test_policy" {
  type        = bool
  description = "Whether to create a test backup policy for PostgreSQL Flexible Server. This policy has minimal retention for testing purposes only."
  default     = true
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - crit4_5 Policy Configuration
# Configuration for the criticality 4/5 backup policy based on MOJ security guidance
# ---------------------------------------------------------------------------------------------------------------------

variable "crit4_5_backup_schedule" {
  type        = string
  description = "ISO 8601 repeating time interval for crit4_5 backups. Default is weekly on Sunday at 02:00 UTC. Format: R/YYYY-MM-DDTHH:MM:SS+00:00/P1W"
  default     = "R/2024-01-07T02:00:00+00:00/P1W"
}

variable "crit4_5_timezone" {
  type        = string
  description = "Timezone for the crit4_5 backup schedule."
  default     = "UTC"
}

variable "crit4_5_default_retention_duration" {
  type        = string
  description = "ISO 8601 duration for default retention of crit4_5 backups. Default is 8 weeks (P56D) per MOJ security guidance for high impact services."
  default     = "P56D"
}

variable "crit4_5_weekly_retention_duration" {
  type        = string
  description = "ISO 8601 duration for weekly retention of crit4_5 backups. Default is 8 weeks (P56D)."
  default     = "P56D"
}

variable "crit4_5_monthly_retention_duration" {
  type        = string
  description = "ISO 8601 duration for monthly point-in-time retention. Default is 1 month. Note: PostgreSQL Flexible Server vaulted backup uses VaultStore only (archive tier not supported)."
  default     = "P1M"
}

variable "crit4_5_yearly_retention_duration" {
  type        = string
  description = "ISO 8601 duration for yearly point-in-time retention. Default is 1 year. Note: PostgreSQL Flexible Server vaulted backup uses VaultStore only (archive tier not supported)."
  default     = "P1Y"
}

variable "crit4_5_enable_extended_retention" {
  type        = bool
  description = "Whether to enable extended long-term retention (monthly and yearly point-in-time). Defaults to true for crit4_5 services but can be opt-out. Note: PostgreSQL Flexible Server vaulted backup stores in VaultStore only (archive tier not supported)."
  default     = true
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Test Policy Configuration
# Configuration for the test backup policy with minimal retention
# ---------------------------------------------------------------------------------------------------------------------

variable "test_backup_schedule" {
  type        = string
  description = "ISO 8601 repeating time interval for test backups. Default is weekly on Sunday at 03:00 UTC."
  default     = "R/2024-01-07T03:00:00+00:00/P1W"
}

variable "test_timezone" {
  type        = string
  description = "Timezone for the test backup schedule."
  default     = "UTC"
}

variable "test_retention_duration" {
  type        = string
  description = "ISO 8601 duration for test backup retention. Default is 1 week (P7D) for minimal cost during testing."
  default     = "P7D"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Tags
# ---------------------------------------------------------------------------------------------------------------------

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the Backup Vault resource."
  default     = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Common HMCTS Tags
# ---------------------------------------------------------------------------------------------------------------------

variable "namespace" {
  type        = string
  description = "Namespace, which could be an organization name or abbreviation, e.g. 'hmcts' or 'cpp'"
  default     = ""
}

variable "costcode" {
  type        = string
  description = "Name of the DWP PRJ number (obtained from the project portfolio in TechNow)"
  default     = ""
}

variable "owner" {
  type        = string
  description = "Name of the project or squad within the PDU which manages the resource."
  default     = ""
}

variable "application" {
  type        = string
  description = "Application to which the resource relates"
  default     = ""
}

variable "environment" {
  type        = string
  description = "Environment into which resource is deployed (e.g., dev, stg, prd)"
  default     = ""
}

variable "type" {
  type        = string
  description = "Name of service type"
  default     = ""
}
