output "resource_group_names" {
  description = "Resource groups created by the pattern."
  value = {
    network  = azurerm_resource_group.network.name
    platform = azurerm_resource_group.platform.name
    gateway  = azurerm_resource_group.gateway.name
    compute  = azurerm_resource_group.compute.name
  }
}

output "vnet_id" { value = module.networking.vnet_id }
output "apim_subnet_id" { value = module.networking.apim_subnet_id }
output "aca_subnet_id" { value = module.networking.aca_subnet_id }
output "pe_subnet_id" { value = module.networking.pe_subnet_id }

output "key_vault_id" { value = module.data.key_vault_id }
output "storage_account_id" { value = module.data.storage_account_id }
output "storage_queue_endpoint" { value = module.data.storage_queue_endpoint }
output "storage_queue_name" { value = module.data.storage_queue_name }
output "acr_id" { value = module.data.acr_id }
output "acr_login_server" { value = module.data.acr_login_server }
output "cosmos_account_id" { value = module.data.cosmos_account_id }
output "search_service_id" { value = module.data.search_service_id }
output "aoai_account_id" { value = module.aoai.account_id }
output "aoai_endpoint" { value = module.aoai.endpoint }

output "foundry_project_id" { value = module.foundry.project_id }
output "foundry_project_endpoint" { value = module.foundry.project_endpoint }

output "apim_id" { value = module.gateway.apim_id }
output "apim_name" { value = module.gateway.apim_name }
output "apim_gateway_url" { value = module.gateway.apim_gateway_url }
output "apim_principal_id" { value = module.gateway.apim_principal_id }

output "container_apps_env_id" { value = module.compute.container_apps_env_id }
output "container_apps_env_name" { value = module.compute.container_apps_env_name }
output "orchestrator_uami_client_id" { value = module.compute.orchestrator_uami_client_id }
output "worker_uami_client_id" { value = module.compute.worker_uami_client_id }
output "e2e_uami_client_id" { value = module.compute.e2e_uami_client_id }
output "e2e_uami_resource_id" { value = module.compute.e2e_uami_resource_id }
output "e2e_job_name" { value = module.compute.e2e_job_name }
