// Foundry module — AI Foundry Hub + Project (kind=Hub / kind=Project) using
// `azapi_resource` with API 2024-10-01-preview, since the azurerm provider
// does not (yet) expose `kind=Hub`/`Project`, `managedNetworkSettings`, or the
// hub-style associated-resources contract. The 2024-10-01-preview surface is
// the GA-equivalent contract for the Foundry Hub/Project pattern; track the
// upstream `Azure/avm-res-machinelearningservices-workspace/azurerm` module
// for a stable replacement.

variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "name_suffix" { type = string }
variable "pe_subnet_id" { type = string }
variable "private_dns_zone_ids" { type = map(string) }
variable "log_analytics_workspace_id" { type = string }
variable "associated_key_vault_id" { type = string }
variable "associated_storage_account_id" { type = string }
variable "associated_container_registry_id" { type = string }
variable "associated_application_insights_id" { type = string }
variable "tags" { type = map(string) }
variable "enable_telemetry" { type = bool }
variable "enable_private_endpoints" { type = bool }
variable "public_network_access" { type = bool }
variable "aoai_endpoint" {
  type        = string
  description = "AOAI endpoint URL for Foundry connection"
}

terraform {
  required_version = ">= 1.12.0, < 2.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    azapi   = { source = "Azure/azapi", version = "~> 2.0" }
  }
}

locals {
  hub_name     = "hub-${var.name_suffix}"
  project_name = "proj-${var.name_suffix}"
}

resource "azapi_resource" "hub" {
  type      = "Microsoft.MachineLearningServices/workspaces@2024-10-01-preview"
  name      = local.hub_name
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  location  = var.location
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "Hub"
    sku  = { name = "Standard", tier = "Standard" }
    properties = {
      friendlyName        = local.hub_name
      keyVault            = var.associated_key_vault_id
      storageAccount      = var.associated_storage_account_id
      containerRegistry   = var.associated_container_registry_id
      applicationInsights = var.associated_application_insights_id
      publicNetworkAccess = var.public_network_access ? "Enabled" : "Disabled"
      managedNetwork = {
        isolationMode = "AllowOnlyApprovedOutbound"
      }
    }
  }

  response_export_values    = ["properties.discoveryUrl", "id", "name"]
  schema_validation_enabled = false
}

resource "azapi_resource" "project" {
  type      = "Microsoft.MachineLearningServices/workspaces@2024-10-01-preview"
  name      = local.project_name
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  location  = var.location
  tags      = var.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    kind = "Project"
    sku  = { name = "Standard", tier = "Standard" }
    properties = {
      friendlyName        = local.project_name
      hubResourceId       = azapi_resource.hub.id
      publicNetworkAccess = var.public_network_access ? "Enabled" : "Disabled"
    }
  }

  response_export_values    = ["properties.discoveryUrl", "id", "name"]
  schema_validation_enabled = false
}

// ---------------- Private endpoint for the Hub ----------------
module "hub_private_endpoint" {
  count = var.enable_private_endpoints ? 1 : 0

  source  = "Azure/avm-res-network-privateendpoint/azurerm"
  version = "0.2.0"

  enable_telemetry                = var.enable_telemetry
  name                            = "pe-${local.hub_name}"
  network_interface_name          = "nic-pe-${local.hub_name}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  subnet_resource_id              = var.pe_subnet_id
  private_connection_resource_id  = azapi_resource.hub.id
  subresource_names               = ["amlworkspace"]
  private_service_connection_name = "psc-foundry-hub"
  private_dns_zone_group_name     = "default"
  private_dns_zone_resource_ids = [
    var.private_dns_zone_ids["privatelink.api.azureml.ms"],
    var.private_dns_zone_ids["privatelink.notebooks.azure.net"],
  ]
  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "hub" {
  name                       = "to-law"
  target_resource_id         = azapi_resource.hub.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "AmlComputeClusterEvent" }
  enabled_log { category = "AmlComputeJobEvent" }
  enabled_metric { category = "AllMetrics" }
}

// ---------------- Foundry Connections (B5: AOAI) ----------------
// Uses azapi_resource for Microsoft.MachineLearningServices/workspaces/connections
// because azurerm provider doesn't expose the 2024-10-01-preview connection API.
resource "azapi_resource" "aoai_connection" {
  type      = "Microsoft.MachineLearningServices/workspaces/connections@2024-10-01-preview"
  name      = "aoai-connection"
  parent_id = azapi_resource.project.id
  tags      = var.tags

  body = {
    properties = {
      category      = "AzureOpenAI"
      target        = var.aoai_endpoint
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiVersion = "2024-10-01"
        ApiType    = "azure"
      }
    }
  }

  response_export_values    = ["properties.category", "properties.target"]
  schema_validation_enabled = false
}

data "azurerm_client_config" "current" {}

// ---------------- Outputs ----------------

output "project_id" {
  value = azapi_resource.project.id
}

output "project_name" {
  value = azapi_resource.project.name
}

// Mirrors the Bicep-emitted endpoint shape.
output "project_endpoint" {
  value = "https://${azapi_resource.project.name}.${var.location}.api.azureml.ms"
}

output "aoai_connection_name" {
  value = azapi_resource.aoai_connection.name
}


