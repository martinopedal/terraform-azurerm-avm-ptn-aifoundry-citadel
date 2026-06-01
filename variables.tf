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

variable "hub_vnet_resource_id" {
  type        = string
  default     = null
  description = "Optional hub VNet resource ID retained for consumers that coordinate peering outside this module. This module does not create hub peering."
}

variable "private_dns_zone_ids" {
  type        = map(string)
  description = "Existing hub-managed Private DNS zone resource IDs keyed by zone name. The module never creates Private DNS zones. Required keys include privatelink.vaultcore.azure.net, privatelink.azurecr.io, privatelink.blob.core.windows.net, privatelink.file.core.windows.net, privatelink.queue.core.windows.net, privatelink.documents.azure.com, privatelink.search.windows.net, privatelink.openai.azure.com, privatelink.api.azureml.ms and privatelink.notebooks.azure.net."
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
