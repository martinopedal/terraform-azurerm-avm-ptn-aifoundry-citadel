// AOAI module — AVM Cognitive Services account + model deployments + hub Private DNS PE.

variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "name_suffix" { type = string }
variable "pe_subnet_id" { type = string }
variable "private_dns_zone_ids" { type = map(string) }
variable "log_analytics_workspace_id" { type = string }
variable "aoai_capacity" {
  type    = number
  default = 30
}
variable "tags" { type = map(string) }
variable "enable_telemetry" { type = bool }

terraform {
  required_version = ">= 1.12.0, < 2.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

data "azurerm_client_config" "current" {}

locals {
  account_name      = "aoai-${var.name_suffix}"
  resource_group_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
}

module "aoai" {
  source  = "Azure/avm-res-cognitiveservices-account/azurerm"
  version = "0.11.0"

  enable_telemetry              = var.enable_telemetry
  name                          = local.account_name
  parent_id                     = local.resource_group_id
  location                      = var.location
  kind                          = "OpenAI"
  sku_name                      = "S0"
  custom_subdomain_name         = local.account_name
  public_network_access_enabled = false
  local_auth_enabled            = false
  managed_identities            = { system_assigned = true }
  network_acls                  = { default_action = "Deny" }
  tags                          = var.tags

  cognitive_deployments = {
    "gpt-4o" = {
      name = "gpt-4o"
      model = {
        format  = "OpenAI"
        name    = "gpt-4o"
        version = "2024-08-06"
      }
      scale = {
        type     = "GlobalStandard"
        capacity = var.aoai_capacity
      }
    }
    "text-embedding-3-large" = {
      name = "text-embedding-3-large"
      model = {
        format  = "OpenAI"
        name    = "text-embedding-3-large"
        version = "1"
      }
      scale = {
        type     = "Standard"
        capacity = 50
      }
    }
  }

  diagnostic_settings = {
    to_law = {
      name                  = "to-law"
      workspace_resource_id = var.log_analytics_workspace_id
      log_categories        = ["Audit", "RequestResponse"]
      metric_categories     = ["AllMetrics"]
    }
  }

  private_endpoints = {
    account = {
      name                            = "pe-${local.account_name}"
      subnet_resource_id              = var.pe_subnet_id
      private_service_connection_name = "psc-aoai"
      private_dns_zone_resource_ids   = [var.private_dns_zone_ids["privatelink.openai.azure.com"]]
      tags                            = var.tags
    }
  }
}

output "account_id" {
  value = module.aoai.resource_id
}

output "account_name" {
  value = module.aoai.name
}

output "endpoint" {
  value = module.aoai.endpoint
}
