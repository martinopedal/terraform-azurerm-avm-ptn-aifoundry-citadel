// Data-plane module — AVM KV, ACR, Storage, Storage Queue, Service Bus, Cosmos DB, AI Search.
// All resources are private and attach PEs to hub-managed Private DNS zones.

variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "name_suffix" { type = string }
variable "pe_subnet_id" { type = string }
variable "private_dns_zone_ids" { type = map(string) }
variable "log_analytics_workspace_id" { type = string }
variable "acr_sku" {
  type    = string
  default = "Premium"
}
variable "search_sku" {
  type    = string
  default = "standard"
}
variable "tags" { type = map(string) }
variable "acr_tasks_subnet_id" {
  type        = string
  description = "Subnet ID for ACR Tasks dedicated agent pool"
}
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
  flat_suffix          = replace(var.name_suffix, "-", "")
  kv_name              = substr("kv${local.flat_suffix}", 0, 24)
  acr_name             = substr("acr${local.flat_suffix}", 0, 24)
  storage_name         = substr("st${local.flat_suffix}", 0, 24)
  foundry_storage_name = substr("stml${local.flat_suffix}", 0, 24)
  cosmos_name          = substr("cosmos-${var.name_suffix}", 0, 44)
  search_name          = "srch-${var.name_suffix}"
  service_bus_name     = substr("sb-${var.name_suffix}", 0, 50)
  storage_queue_name   = "orchestrator-to-worker"
  service_bus_queue    = "orchestrator-to-worker"
  resource_group_id    = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  diag_all = {
    to_law = {
      name                  = "to-law"
      workspace_resource_id = var.log_analytics_workspace_id
      log_groups            = ["allLogs"]
      metric_categories     = ["AllMetrics"]
    }
  }

  deployer_uami_tag = try(var.tags.deployerUami, null)
  canonical_deployer_uami_tag = local.deployer_uami_tag == null ? null : replace(
    replace(local.deployer_uami_tag, "resourcegroups", "resourceGroups"),
    "providers/microsoft.managedidentity/userassignedidentities",
    "providers/Microsoft.ManagedIdentity/userAssignedIdentities"
  )
  acr_agent_pool_tags = local.canonical_deployer_uami_tag == null ? var.tags : merge(var.tags, {
    deployerUami = local.canonical_deployer_uami_tag
  })
}

module "service_bus" {
  source  = "Azure/avm-res-servicebus-namespace/azurerm"
  version = "0.4.0"

  enable_telemetry              = var.enable_telemetry
  name                          = local.service_bus_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Standard"
  local_auth_enabled            = false
  public_network_access_enabled = false
  tags                          = var.tags
  diagnostic_settings           = local.diag_all

  queues = {
    orchestrator_to_worker = {
      name                                    = local.service_bus_queue
      dead_lettering_on_message_expiration    = true
      max_delivery_count                      = 10
      requires_duplicate_detection            = false
      requires_session                        = false
      duplicate_detection_history_time_window = "PT10M"
    }
  }

  private_endpoints = {
    namespace = {
      name                            = "pe-${local.service_bus_name}"
      subnet_resource_id              = var.pe_subnet_id
      private_service_connection_name = "psc-sb"
      private_dns_zone_resource_ids   = [var.private_dns_zone_ids["privatelink.servicebus.windows.net"]]
      tags                            = var.tags
    }
  }
}

module "key_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "0.10.2"

  enable_telemetry               = var.enable_telemetry
  name                           = local.kv_name
  location                       = var.location
  resource_group_name            = var.resource_group_name
  tenant_id                      = data.azurerm_client_config.current.tenant_id
  sku_name                       = "standard"
  legacy_access_policies_enabled = false
  purge_protection_enabled       = true
  soft_delete_retention_days     = 90
  public_network_access_enabled  = false
  network_acls                   = { default_action = "Deny", bypass = "AzureServices" }
  tags                           = var.tags
  diagnostic_settings            = local.diag_all

  private_endpoints = {
    vault = {
      name                            = "pe-${local.kv_name}"
      subnet_resource_id              = var.pe_subnet_id
      private_service_connection_name = "psc-kv"
      private_dns_zone_resource_ids   = [var.private_dns_zone_ids["privatelink.vaultcore.azure.net"]]
      tags                            = var.tags
    }
  }
}

module "acr" {
  source  = "Azure/avm-res-containerregistry-registry/azurerm"
  version = "0.5.1"

  enable_telemetry              = var.enable_telemetry
  name                          = local.acr_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.acr_sku
  admin_enabled                 = false
  public_network_access_enabled = true
  zone_redundancy_enabled       = true
  network_rule_bypass_option    = "AzureServices"
  network_rule_set = {
    default_action = "Deny"
    ip_rule        = []
  }
  tags                = var.tags
  diagnostic_settings = local.diag_all

  private_endpoints = {
    registry = {
      name                            = "pe-${local.acr_name}"
      subnet_resource_id              = var.pe_subnet_id
      private_service_connection_name = "psc-acr"
      private_dns_zone_resource_ids   = [var.private_dns_zone_ids["privatelink.azurecr.io"]]
      tags                            = var.tags
    }
  }
}

module "storage" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.7.2"

  enable_telemetry                = var.enable_telemetry
  name                            = local.storage_name
  parent_id                       = local.resource_group_id
  location                        = var.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  is_hns_enabled                  = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  network_rules                   = { default_action = "Deny", bypass = ["AzureServices"] }
  tags                            = var.tags

  queues = {
    orchestrator_to_worker = {
      name = local.storage_queue_name
    }
  }

  private_endpoints = {
    blob = {
      name                            = "pe-${local.storage_name}-blob"
      subnet_resource_id              = var.pe_subnet_id
      subresource_name                = "blob"
      private_service_connection_name = "psc-blob"
      private_dns_zone_resource_ids   = [var.private_dns_zone_ids["privatelink.blob.core.windows.net"]]
      tags                            = var.tags
    }
    file = {
      name                            = "pe-${local.storage_name}-file"
      subnet_resource_id              = var.pe_subnet_id
      subresource_name                = "file"
      private_service_connection_name = "psc-file"
      private_dns_zone_resource_ids   = [var.private_dns_zone_ids["privatelink.file.core.windows.net"]]
      tags                            = var.tags
    }
    queue = {
      name                            = "pe-${local.storage_name}-queue"
      subnet_resource_id              = var.pe_subnet_id
      subresource_name                = "queue"
      private_service_connection_name = "psc-queue"
      private_dns_zone_resource_ids   = [var.private_dns_zone_ids["privatelink.queue.core.windows.net"]]
      tags                            = var.tags
    }
  }
}

module "foundry_storage" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.7.2"

  enable_telemetry                = var.enable_telemetry
  name                            = local.foundry_storage_name
  parent_id                       = local.resource_group_id
  location                        = var.location
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "ZRS"
  is_hns_enabled                  = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = false
  network_rules                   = { default_action = "Deny", bypass = ["AzureServices"] }
  tags                            = var.tags

  private_endpoints = {
    blob = {
      name                            = "pe-${local.foundry_storage_name}-blob"
      subnet_resource_id              = var.pe_subnet_id
      subresource_name                = "blob"
      private_service_connection_name = "psc-foundry-blob"
      private_dns_zone_resource_ids   = [var.private_dns_zone_ids["privatelink.blob.core.windows.net"]]
      tags                            = var.tags
    }
  }
}

module "cosmos" {
  source  = "Azure/avm-res-documentdb-databaseaccount/azurerm"
  version = "0.10.0"

  enable_telemetry                      = var.enable_telemetry
  name                                  = local.cosmos_name
  location                              = var.location
  resource_group_name                   = var.resource_group_name
  public_network_access_enabled         = false
  local_authentication_disabled         = true
  network_acl_bypass_for_azure_services = true
  consistency_policy                    = { consistency_level = "Session" }
  geo_locations                         = [{ location = var.location, failover_priority = 0, zone_redundant = true }]
  capabilities                          = [{ name = "EnableServerless" }, { name = "EnableNoSQLVectorSearch" }]
  tags                                  = var.tags
  diagnostic_settings = {
    to_law = {
      name                  = "to-law"
      workspace_resource_id = var.log_analytics_workspace_id
      log_categories        = ["DataPlaneRequests", "QueryRuntimeStatistics", "ControlPlaneRequests"]
      metric_categories     = ["Requests"]
    }
  }

  # Citadel AI usage ingestion schema (5 containers)
  # Source: Azure-Samples/ai-hub-gateway-solution-accelerator @ citadel-v1 SHA f2702b49
  # bicep/infra/modules/cosmos-db/cosmos-db.bicep
  sql_databases = {
    ai_usage_db = {
      name = "ai-usage-db"
      containers = {
        ai_usage_container = {
          name                = "ai-usage-container"
          partition_key_paths = ["/productName"]
        }
        model_pricing = {
          name                = "model-pricing"
          partition_key_paths = ["/model"]
        }
        pii_usage_container = {
          name                = "pii-usage-container"
          partition_key_paths = ["/type"]
        }
        llm_usage_container = {
          name                = "llm-usage-container"
          partition_key_paths = ["/productName"]
        }
        streaming_export_config = {
          name                = "streaming-export-config"
          partition_key_paths = ["/type"]
        }
      }
    }
  }

  private_endpoints = {
    sql = {
      name                            = "pe-${local.cosmos_name}"
      subnet_resource_id              = var.pe_subnet_id
      subresource_name                = "Sql"
      private_service_connection_name = "psc-cosmos"
      private_dns_zone_resource_ids   = [var.private_dns_zone_ids["privatelink.documents.azure.com"]]
      tags                            = var.tags
    }
  }
}

module "search" {
  source  = "Azure/avm-res-search-searchservice/azurerm"
  version = "0.2.0"

  enable_telemetry              = var.enable_telemetry
  name                          = local.search_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.search_sku
  public_network_access_enabled = false
  semantic_search_sku           = "standard"
  local_authentication_enabled  = false
  managed_identities            = { system_assigned = true }
  tags                          = var.tags
  diagnostic_settings           = local.diag_all

  private_endpoints = {
    search = {
      name                            = "pe-${local.search_name}"
      subnet_resource_id              = var.pe_subnet_id
      private_service_connection_name = "psc-search"
      private_dns_zone_resource_ids   = [var.private_dns_zone_ids["privatelink.search.windows.net"]]
      tags                            = var.tags
    }
  }
}

// TODO(avm): ACR dedicated agent pools are still modeled with AzAPI because the published
// ACR AVM does not currently expose registry agent pools.
resource "azapi_resource" "acr_agent_pool" {
  type      = "Microsoft.ContainerRegistry/registries/agentPools@2019-06-01-preview"
  name      = "acrtasks-pool"
  parent_id = module.acr.resource_id
  location  = var.location
  tags      = local.acr_agent_pool_tags

  body = {
    properties = {
      count                          = 1
      tier                           = "S1"
      os                             = "Linux"
      virtualNetworkSubnetResourceId = var.acr_tasks_subnet_id
    }
  }
}

output "key_vault_id" { value = module.key_vault.resource_id }
output "key_vault_uri" { value = module.key_vault.uri }
output "acr_id" { value = module.acr.resource_id }
output "acr_login_server" { value = module.acr.resource.login_server }
output "storage_account_id" { value = module.storage.resource_id }
output "foundry_storage_account_id" { value = module.foundry_storage.resource_id }
output "cosmos_account_id" { value = module.cosmos.resource_id }
output "search_service_id" { value = module.search.resource_id }
output "storage_queue_endpoint" { value = "https://${module.storage.name}.queue.core.windows.net" }
output "storage_queue_name" { value = module.storage.queues["orchestrator_to_worker"].name }
output "service_bus_namespace_id" { value = module.service_bus.resource_id }
output "service_bus_fqdn" { value = "${local.service_bus_name}.servicebus.windows.net" }
output "service_bus_queue_orchestrator_to_worker" { value = module.service_bus.resource_queues["orchestrator-to-worker"].name }
output "acr_tasks_agent_pool_name" { value = azapi_resource.acr_agent_pool.name }
output "acr_name" { value = module.acr.name }
