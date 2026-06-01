// Gateway module — AVM APIM in classic Internal VNet mode + GenAI named values.

variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "name_suffix" { type = string }
variable "apim_subnet_id" { type = string }
variable "apim_sku" {
  type        = string
  description = "APIM SKU (e.g. Developer_1, Premium_2)."
  default     = "Developer_1"
}
variable "zones" {
  type    = list(string)
  default = []
}
variable "log_analytics_workspace_id" { type = string }
variable "application_insights_id" { type = string }
variable "application_insights_instrumentation_key" {
  type      = string
  sensitive = true
}
variable "aoai_endpoint" { type = string }
variable "foundry_project_endpoint" { type = string }
variable "tenant_id" { type = string }
variable "tags" { type = map(string) }
variable "enable_telemetry" { type = bool }

terraform {
  required_version = ">= 1.12.0, < 2.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

module "apim" {
  source  = "Azure/avm-res-apimanagement-service/azurerm"
  version = "0.9.0"

  enable_telemetry          = var.enable_telemetry
  name                      = "apim-${var.name_suffix}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  publisher_name            = "AI Platform Team"
  publisher_email           = "ai-platform@dnb.no"
  sku_name                  = var.apim_sku
  zones                     = var.zones
  virtual_network_type      = "Internal"
  virtual_network_subnet_id = var.apim_subnet_id
  managed_identities        = { system_assigned = true }
  tags                      = var.tags

  named_values = {
    aoai_endpoint = {
      display_name = "aoai-endpoint"
      value        = var.aoai_endpoint
      secret       = false
    }
    foundry_project_endpoint = {
      display_name = "foundry-project-endpoint"
      value        = var.foundry_project_endpoint
      secret       = false
    }
    tenant_id = {
      display_name = "tenant-id"
      value        = var.tenant_id
      secret       = false
    }
    appi_instrumentation_key = {
      display_name = "appi-instrumentation-key"
      value        = var.application_insights_instrumentation_key
      secret       = true
    }
  }

  diagnostic_settings = {
    to_law = {
      name                  = "to-law"
      workspace_resource_id = var.log_analytics_workspace_id
      log_categories        = ["GatewayLogs", "WebSocketConnectionLogs"]
      metric_categories     = ["AllMetrics"]
    }
  }
}

// TODO(avm): Keep the APIM logger as azurerm until the APIM AVM exposes logger wiring.
resource "azurerm_api_management_logger" "appi" {
  name                = "appi"
  api_management_name = module.apim.name
  resource_group_name = var.resource_group_name
  resource_id         = var.application_insights_id

  application_insights {
    instrumentation_key = var.application_insights_instrumentation_key
  }
}


output "apim_name" { value = module.apim.name }
output "apim_id" { value = module.apim.resource_id }
output "apim_gateway_url" { value = module.apim.apim_gateway_url }
output "apim_principal_id" { value = module.apim.workspace_identity.principal_id }
