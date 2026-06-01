terraform {
  required_version = ">= 1.12.0, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

module "citadel" {
  source = "../.."

  name_prefix         = "citadel"
  environment         = "dev"
  location            = "swedencentral"
  spoke_address_space = "10.16.4.0/24"
  network_group_tag   = "aifoundry-spokes"

  private_dns_zone_ids = {
    "privatelink.api.azureml.ms"         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/privateDnsZones/privatelink.api.azureml.ms"
    "privatelink.azurecr.io"             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
    "privatelink.blob.core.windows.net"  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    "privatelink.documents.azure.com"    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com"
    "privatelink.file.core.windows.net"  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net"
    "privatelink.notebooks.azure.net"    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/privateDnsZones/privatelink.notebooks.azure.net"
    "privatelink.openai.azure.com"       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com"
    "privatelink.queue.core.windows.net" = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net"
    "privatelink.search.windows.net"     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net"
    "privatelink.vaultcore.azure.net"    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
  }

  tags = {
    workload   = "aifoundry-citadel"
    managedBy  = "terraform"
    costCenter = "example"
  }
}
