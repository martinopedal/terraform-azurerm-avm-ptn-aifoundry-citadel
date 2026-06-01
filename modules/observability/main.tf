// Observability module — AVM Log Analytics workspace + Application Insights.

variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "name_suffix" { type = string }
variable "tags" { type = map(string) }
variable "enable_telemetry" { type = bool }

terraform {
  required_version = ">= 1.12.0, < 2.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

module "log_analytics" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.5.1"

  enable_telemetry                                   = var.enable_telemetry
  name                                               = "log-${var.name_suffix}"
  location                                           = var.location
  resource_group_name                                = var.resource_group_name
  log_analytics_workspace_sku                        = "PerGB2018"
  log_analytics_workspace_retention_in_days          = 30
  log_analytics_workspace_internet_ingestion_enabled = "false"
  log_analytics_workspace_internet_query_enabled     = "false"
  tags                                               = var.tags
}

module "application_insights" {
  source  = "Azure/avm-res-insights-component/azurerm"
  version = "0.4.0"

  enable_telemetry           = var.enable_telemetry
  name                       = "appi-${var.name_suffix}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  workspace_id               = module.log_analytics.resource_id
  application_type           = "web"
  internet_ingestion_enabled = false
  internet_query_enabled     = false
  tags                       = var.tags
}

output "log_analytics_workspace_id" {
  value = module.log_analytics.resource_id
}

output "application_insights_id" {
  value = module.application_insights.resource_id
}

output "application_insights_connection_string" {
  value     = module.application_insights.connection_string
  sensitive = true
}

output "application_insights_instrumentation_key" {
  value     = module.application_insights.instrumentation_key
  sensitive = true
}
