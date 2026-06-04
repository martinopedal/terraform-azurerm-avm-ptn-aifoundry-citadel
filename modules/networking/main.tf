// Networking module — Foundry spoke VNet, carved from var.address_space.
// Optional AVNM membership can be tag-driven via the network-group tag; no hub peering is created here.

variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "name_suffix" { type = string }
variable "address_space" { type = string }
variable "hub_vnet_resource_id" {
  type    = string
  default = null
}
variable "tags" { type = map(string) }
variable "enable_telemetry" { type = bool }

terraform {
  required_version = ">= 1.12.0, < 2.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    azapi   = { source = "Azure/azapi", version = "~> 2.0" }
  }
}

data "azurerm_client_config" "current" {}

locals {
  resource_group_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  subnets = {
    # /24 layout: APIM /27, ACA /27, private endpoints /26, AGW /27, integration /27, funcapp /26, agent /26.
    "snet-apim" = {
      prefix      = cidrsubnet(var.address_space, 3, 0)
      delegation  = null
      pe_policies = "Enabled"
      nsg         = "nsg-apim"
    }
    "snet-aca" = {
      prefix      = cidrsubnet(var.address_space, 3, 1)
      delegation  = "Microsoft.App/environments"
      pe_policies = "Enabled"
      nsg         = "nsg-aca"
    }
    "snet-pe" = {
      prefix      = cidrsubnet(var.address_space, 2, 1)
      delegation  = null
      pe_policies = "Disabled"
      nsg         = "nsg-pe"
    }
    "snet-agw" = {
      prefix      = cidrsubnet(var.address_space, 3, 4)
      delegation  = null
      pe_policies = "Enabled"
      nsg         = "nsg-agw"
    }
    "snet-integration" = {
      prefix      = cidrsubnet(var.address_space, 3, 5)
      delegation  = null
      pe_policies = "Enabled"
      nsg         = "nsg-int"
    }
    # Citadel AI Gateway integration subnets (from citadel-v1 networking.bicep)
    "snet-funcapp" = {
      prefix      = cidrsubnet(var.address_space, 2, 2) # /26 for Function App VNet integration
      delegation  = "Microsoft.Web/serverFarms"
      pe_policies = "Enabled"
      nsg         = "nsg-funcapp"
    }
    "snet-agent" = {
      prefix      = cidrsubnet(var.address_space, 2, 3) # /26 for AI Foundry agent network injection
      delegation  = "Microsoft.App/environments"
      pe_policies = "Enabled"
      nsg         = "nsg-agent"
    }
  }

  nsgs = toset([for subnet in values(local.subnets) : subnet.nsg])
}

resource "azurerm_network_security_group" "this" {
  for_each            = local.nsgs
  name                = "${each.value}-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

module "spoke" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "0.17.1"

  enable_telemetry = var.enable_telemetry
  name             = "vnet-${var.name_suffix}"
  location         = var.location
  parent_id        = local.resource_group_id
  address_space    = [var.address_space]
  tags             = var.tags

  subnets = {
    for name, subnet in local.subnets : name => {
      name                              = name
      address_prefix                    = subnet.prefix
      default_outbound_access_enabled   = name == "snet-integration"
      private_endpoint_network_policies = subnet.pe_policies
      network_security_group            = { id = azurerm_network_security_group.this[subnet.nsg].id }
      delegations = subnet.delegation == null ? [] : [{
        name = "delegation"
        service_delegation = {
          name = subnet.delegation
        }
      }]
    }
  }
}

output "vnet_id" {
  value = module.spoke.resource_id
}

output "apim_subnet_id" {
  value = module.spoke.subnets["snet-apim"].resource_id
}

output "aca_subnet_id" {
  value = module.spoke.subnets["snet-aca"].resource_id
}

output "pe_subnet_id" {
  value = module.spoke.subnets["snet-pe"].resource_id
}

output "integration_subnet_id" {
  value = module.spoke.subnets["snet-integration"].resource_id
}

output "acr_tasks_subnet_id" {
  value = module.spoke.subnets["snet-integration"].resource_id
}

output "funcapp_subnet_id" {
  value       = module.spoke.subnets["snet-funcapp"].resource_id
  description = "Function App VNet integration subnet ID (Citadel usage ingestion worker)"
}

output "agent_subnet_id" {
  value       = module.spoke.subnets["snet-agent"].resource_id
  description = "AI Foundry agent network injection subnet ID (Citadel agents)"
}
