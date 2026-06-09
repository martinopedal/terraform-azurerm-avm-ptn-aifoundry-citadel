variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name used for naming and SKU selection."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of dev/test/prod."
  }
}

variable "location" {
  type        = string
  default     = "swedencentral"
  description = "Azure region for resources."
}

variable "name_prefix" {
  type        = string
  default     = "citadel"
  description = "Short workload prefix used in resource names. Keep <= 8 characters for Azure name limits."

  validation {
    condition     = length(var.name_prefix) <= 8
    error_message = "name_prefix must be 8 characters or fewer."
  }
}

variable "resource_group_names" {
  type = object({
    network  = optional(string)
    platform = optional(string)
    gateway  = optional(string)
    compute  = optional(string)
  })
  default     = {}
  description = "Optional resource group names. Defaults to rg-<name_prefix>-<environment>-<location>-<layer>."
}

variable "spoke_address_space" {
  type        = string
  default     = "10.16.4.0/24"
  description = "Spoke VNet CIDR. The networking module carves APIM, ACA, PE, App Gateway and integration subnets from this CIDR."
}

variable "enable_extra_citadel_subnets" {
  type        = bool
  default     = true
  description = "Create additional Citadel function/agent subnets. Disable when migrating an existing spoke whose /24 is already fully allocated."
}

variable "container_app_workload_profiles" {
  type = list(object({
    name                  = string
    workload_profile_type = string
    minimum_count         = optional(number)
    maximum_count         = optional(number)
  }))
  default = [{
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }]
  description = "Container Apps Environment workload profiles."
}

variable "hub_vnet_resource_id" {
  type        = string
  default     = null
  description = "Optional hub VNet resource ID retained for consumers that coordinate peering outside this module. This module does not create hub peering."
}

variable "spoke_dns_servers" {
  type        = list(string)
  default     = ["10.0.0.4"]
  description = "DNS servers assigned to the spoke VNet. Default points governed spokes at the hub Azure Firewall DNS proxy."
}

variable "private_dns_zone_ids" {
  type        = map(string)
  description = "Existing hub-managed Private DNS zone resource IDs keyed by zone name. The module never creates Private DNS zones. Required keys include privatelink.vaultcore.azure.net, privatelink.azurecr.io, privatelink.blob.core.windows.net, privatelink.file.core.windows.net, privatelink.queue.core.windows.net, privatelink.servicebus.windows.net, privatelink.documents.azure.com, privatelink.search.windows.net, privatelink.openai.azure.com, privatelink.api.azureml.ms and privatelink.notebooks.azure.net."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources."
}

variable "network_group_tag" {
  type        = string
  default     = null
  description = "Optional value for the network-group tag, for environments where AVNM membership is tag-driven."
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = "Controls telemetry for consumed Azure Verified Modules."
}

variable "git_sha" {
  type        = string
  default     = "latest"
  description = "Default container image tag for placeholder Container Apps/Jobs."
}



# ============================================================================
# COST & TIER CONTROLS
# ============================================================================

# -------------------- MODEL DEPLOYMENTS --------------------

# cost: List of AOAI model deployments. Default = single gpt-4o-mini (Standard, cheap).
# Opt-in: add more models, use Provisioned/PTU for reserved throughput (expensive).
variable "aoai_deployments" {
  type = list(object({
    name    = string
    model   = string
    version = string
    # cost: Standard = pay-per-token (cheap); GlobalStandard = global routing (cheap); Provisioned = reserved throughput (expensive, PTU).
    sku_type = string
    capacity = number
  }))
  default = [
    {
      name     = "gpt-4o-mini"
      model    = "gpt-4o-mini"
      version  = "2024-07-18"
      sku_type = "Standard"
      capacity = 10 # 10K TPM = minimal baseline
    }
  ]
  description = "AOAI model deployments. Each entry: name, model, version, sku_type (Standard/GlobalStandard/Provisioned), capacity (TPM for Standard/GlobalStandard, PTU for Provisioned)."
}

# -------------------- SECURITY CONTROLS --------------------

# cost: Private endpoints add ~$7.30/mo per PE. Default true (private-by-default ALZ posture).
variable "enable_private_endpoints" {
  type        = bool
  default     = true
  description = "Enable private endpoints for Foundry, AOAI, Storage, Key Vault, ACR, Cosmos, and Search. Disable for dev-only scenarios (not recommended)."
}

# cost: No direct cost impact. Default false = private-only access (ALZ demo default).
# Opt-in: true = allow public network access to Foundry hub/project and AOAI account (requires explicit opt-in per ALZ security policy).
variable "public_network_access_enabled" {
  type        = bool
  default     = false
  description = "Allow public network access to Foundry and AOAI. Default false enforces private-only (ALZ demo default). Set true only for explicitly public demos."
}

# cost: No direct cost. Default true = AAD-only auth (recommended). Set false to allow shared-key auth (legacy, not recommended).
variable "disable_local_auth" {
  type        = bool
  default     = true
  description = "Disable local/shared-key authentication on AOAI account (enforce AAD-only). Recommended for production."
}

# cost: Customer-managed keys require Key Vault Premium (~$3/mo extra) + operational complexity. Default false (Microsoft-managed keys, cheap).
variable "enable_cmk" {
  type        = bool
  default     = false
  description = "Enable customer-managed key encryption for Foundry workspace and AOAI account. Requires Key Vault Premium. Default false (Microsoft-managed keys)."
}

# -------------------- RELIABILITY CONTROLS --------------------

# cost: Zone redundancy varies by service. ACA: +50% cost. APIM Premium: included. AOAI/Foundry: region-dependent, may not be available. Default false (cheap).
variable "enable_zone_redundancy" {
  type        = bool
  default     = false
  description = "Enable zone redundancy for Container Apps Environment and APIM (when prod SKU). Note: AOAI and Foundry zone redundancy is region-dependent; module does not currently configure it."
}

# cost: Log retention beyond 30 days incurs storage cost. Default 30 (cheap). Opt-in to 90+ for compliance.
variable "diagnostic_retention_days" {
  type        = number
  default     = 30
  description = "Diagnostic log retention in days. Default 30 (cheap baseline). Increase for compliance needs (90, 180, 365)."
}

# -------------------- E2E TEST JOB --------------------

variable "e2e_job_image" {
  type        = string
  default     = "mcr.microsoft.com/azure-cli:latest"
  description = "Container image for the e2e test job. Default is mcr.microsoft.com/azure-cli:latest; for private networks use an ACR-imported copy (e.g., acrname.azurecr.io/azure-cli:latest)."
}

variable "enable_e2e_job" {
  description = "Enable creation of the e2e test Container App Job. Set to false to skip e2e job deployment (useful when troubleshooting DNS/networking issues)."
  type        = bool
  default     = true
}
