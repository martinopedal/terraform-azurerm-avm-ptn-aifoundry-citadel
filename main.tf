data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "network" {
  name     = local.rg_network
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "platform" {
  name     = local.rg_platform
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "gateway" {
  name     = local.rg_gateway
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "compute" {
  name     = local.rg_compute
  location = var.location
  tags     = local.tags
}

module "networking" {
  source = "./modules/networking"

  location                     = var.location
  resource_group_name          = azurerm_resource_group.network.name
  name_suffix                  = local.name_suffix
  address_space                = var.spoke_address_space
  hub_vnet_resource_id         = var.hub_vnet_resource_id
  dns_servers                  = var.spoke_dns_servers
  enable_extra_citadel_subnets = var.enable_extra_citadel_subnets
  enable_telemetry             = var.enable_telemetry
  tags                         = local.tags
}

module "observability" {
  source = "./modules/observability"

  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name
  name_suffix         = local.name_suffix
  enable_telemetry    = var.enable_telemetry
  tags                = local.tags
}

module "data" {
  source = "./modules/data"

  location                   = var.location
  resource_group_name        = azurerm_resource_group.platform.name
  name_suffix                = local.name_suffix
  pe_subnet_id               = module.networking.pe_subnet_id
  private_dns_zone_ids       = var.private_dns_zone_ids
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  acr_sku                    = local.sku.acr
  search_sku                 = local.sku.search
  acr_tasks_subnet_id        = module.networking.acr_tasks_subnet_id
  enable_telemetry           = var.enable_telemetry
  tags                       = local.tags
}

module "aoai" {
  source = "./modules/aoai"

  location                   = var.location
  resource_group_name        = azurerm_resource_group.platform.name
  name_suffix                = local.name_suffix
  pe_subnet_id               = module.networking.pe_subnet_id
  private_dns_zone_ids       = var.private_dns_zone_ids
  log_analytics_workspace_id = module.observability.log_analytics_workspace_id
  aoai_deployments           = var.aoai_deployments
  enable_private_endpoints   = var.enable_private_endpoints
  public_network_access      = var.public_network_access_enabled
  disable_local_auth         = var.disable_local_auth
  enable_telemetry           = var.enable_telemetry
  tags                       = local.tags
}

module "foundry" {
  source = "./modules/foundry"

  location                           = var.location
  resource_group_name                = azurerm_resource_group.platform.name
  name_suffix                        = local.name_suffix
  pe_subnet_id                       = module.networking.pe_subnet_id
  private_dns_zone_ids               = var.private_dns_zone_ids
  log_analytics_workspace_id         = module.observability.log_analytics_workspace_id
  associated_key_vault_id            = module.data.key_vault_id
  associated_storage_account_id      = module.data.foundry_storage_account_id
  associated_container_registry_id   = module.data.acr_id
  associated_application_insights_id = module.observability.application_insights_id
  aoai_endpoint                      = module.aoai.endpoint
  enable_private_endpoints           = var.enable_private_endpoints
  public_network_access              = var.public_network_access_enabled
  enable_telemetry                   = var.enable_telemetry
  tags                               = local.tags
}

module "gateway" {
  source = "./modules/gateway"

  location                                 = var.location
  resource_group_name                      = azurerm_resource_group.gateway.name
  name_suffix                              = local.name_suffix
  apim_subnet_id                           = module.networking.apim_subnet_id
  apim_sku                                 = local.apim_sku
  zones                                    = local.apim_zones
  log_analytics_workspace_id               = module.observability.log_analytics_workspace_id
  application_insights_id                  = module.observability.application_insights_id
  application_insights_instrumentation_key = module.observability.application_insights_instrumentation_key
  aoai_endpoint                            = module.aoai.endpoint
  aoai_resource_id                         = module.aoai.account_id
  foundry_project_endpoint                 = module.foundry.project_endpoint
  tenant_id                                = data.azurerm_client_config.current.tenant_id
  enable_telemetry                         = var.enable_telemetry
  tags                                     = local.gateway_tags
}

module "compute" {
  source = "./modules/compute"

  location                               = var.location
  resource_group_name                    = azurerm_resource_group.compute.name
  name_suffix                            = local.name_suffix
  aca_subnet_id                          = module.networking.aca_subnet_id
  log_analytics_workspace_id             = module.observability.log_analytics_workspace_id
  application_insights_connection_string = module.observability.application_insights_connection_string
  zone_redundant                         = var.enable_zone_redundancy
  workload_profiles                      = var.container_app_workload_profiles
  acr_id                                 = module.data.acr_id
  acr_login_server                       = module.data.acr_login_server
  service_bus_namespace_id               = module.data.service_bus_namespace_id
  service_bus_queue_name                 = module.data.service_bus_queue_orchestrator_to_worker
  key_vault_id                           = module.data.key_vault_id
  storage_queue_endpoint                 = module.data.storage_queue_endpoint
  storage_queue_name                     = module.data.storage_queue_name
  apim_gateway_url                       = module.gateway.apim_gateway_url
  foundry_project_endpoint               = module.foundry.project_endpoint
  foundry_project_id                     = module.foundry.project_id
  git_sha                                = var.git_sha
  env_name                               = var.environment
  enable_telemetry                       = var.enable_telemetry
  tags                                   = local.tags
}
