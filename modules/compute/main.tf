// Compute module — AVM Container Apps managed environment, internal load balancer,
// Consumption-only. AKS is intentionally not provisioned day-1.
//
// R2 additions: orchestrator/worker UAMIs + Container Apps, e2e Container App Job,
// role assignments per CONTRACT.md matrix.

variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "name_suffix" { type = string }
variable "aca_subnet_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "application_insights_connection_string" {
  type      = string
  sensitive = true
}
variable "zone_redundant" {
  type    = bool
  default = true
}
variable "tags" { type = map(string) }
variable "enable_telemetry" { type = bool }
variable "workload_profiles" {
  type = list(object({
    name                  = string
    workload_profile_type = string
    minimum_count         = optional(number)
    maximum_count         = optional(number)
  }))
  default = [{
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }]
  description = "Container Apps Environment workload profiles."
}

// R2 dependencies from other modules
variable "storage_queue_endpoint" { type = string }
variable "storage_queue_name" { type = string }
variable "acr_id" { type = string }
variable "service_bus_namespace_id" { type = string }
variable "service_bus_queue_name" { type = string }
variable "key_vault_id" { type = string }
variable "foundry_project_id" {
  description = "Foundry project resource ID for e2e Reader access."
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "acr_login_server" {
  description = "ACR login server (consumed when Container Apps uncommented)"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "apim_gateway_url" {
  description = "APIM gateway URL (consumed when Container Apps uncommented)"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "foundry_project_endpoint" {
  description = "Foundry project endpoint (consumed when Container Apps uncommented)"
  type        = string
}

# tflint-ignore: terraform_unused_declarations
variable "apim_subscription_key_secret_name" {
  description = "Key Vault secret name for APIM subscription key (consumed when Container Apps uncommented)"
  type        = string
  default     = "apim-subscription-key"
}

# tflint-ignore: terraform_unused_declarations
variable "git_sha" {
  description = "Git commit SHA for container image tags (consumed when Container Apps uncommented)"
  type        = string
  default     = "latest"
}

# tflint-ignore: terraform_unused_declarations
variable "env_name" {
  description = "Environment name for container image tags (consumed when Container Apps uncommented)"
  type        = string
  default     = "dev"
}

terraform {
  required_version = ">= 1.12.0, < 2.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    azapi   = { source = "Azure/azapi", version = "~> 2.0" }
  }
}

locals {
  sb_namespace_name = element(split("/", var.service_bus_namespace_id), length(split("/", var.service_bus_namespace_id)) - 1)
  service_bus_fqdn  = "${local.sb_namespace_name}.servicebus.windows.net"
  cae_deployer_uami_tag = try(
    replace(
      var.tags.deployerUami,
      "/providers/microsoft.managedidentity/userassignedidentities/",
      "/providers/Microsoft.ManagedIdentity/userAssignedIdentities/"
    ),
    null
  )
  managed_environment_tags = local.cae_deployer_uami_tag == null ? var.tags : merge(var.tags, {
    deployerUami = local.cae_deployer_uami_tag
  })
}

// =====================================================================
// Container Apps Environment
// =====================================================================
module "managed_environment" {
  source  = "Azure/avm-res-app-managedenvironment/azurerm"
  version = "0.5.0"

  enable_telemetry              = var.enable_telemetry
  name                          = "cae-${var.name_suffix}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  infrastructure_resource_group = "${var.resource_group_name}-infra"
  zone_redundant                = var.zone_redundant
  log_analytics_workspace       = { resource_id = var.log_analytics_workspace_id }
  vnet_configuration = {
    infrastructure_subnet_id = var.aca_subnet_id
    internal                 = true
  }
  workload_profiles = var.workload_profiles
  tags              = local.managed_environment_tags
}

// =====================================================================
// R2: Runtime User-Assigned Managed Identities
// =====================================================================
resource "azurerm_user_assigned_identity" "orchestrator" {
  name                = "uami-orchestrator-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "worker" {
  name                = "uami-worker-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "e2e" {
  name                = "uami-e2e-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "orchestrator_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.orchestrator.principal_id
}

resource "azurerm_role_assignment" "orchestrator_sb_sender" {
  scope                = "${var.service_bus_namespace_id}/queues/${var.service_bus_queue_name}"
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_user_assigned_identity.orchestrator.principal_id
}

resource "azurerm_role_assignment" "orchestrator_kv_secrets" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.orchestrator.principal_id
}

resource "azurerm_role_assignment" "worker_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

resource "azurerm_role_assignment" "worker_sb_receiver" {
  scope                = "${var.service_bus_namespace_id}/queues/${var.service_bus_queue_name}"
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

resource "azurerm_role_assignment" "worker_kv_secrets" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.worker.principal_id
}

resource "azurerm_role_assignment" "e2e_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.e2e.principal_id
}

resource "azurerm_role_assignment" "e2e_law_reader" {
  scope                = var.log_analytics_workspace_id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_user_assigned_identity.e2e.principal_id
}

resource "azurerm_role_assignment" "e2e_sb_sender" {
  scope                = var.service_bus_namespace_id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_user_assigned_identity.e2e.principal_id
}

resource "azurerm_role_assignment" "e2e_sb_receiver" {
  scope                = var.service_bus_namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.e2e.principal_id
}

resource "azurerm_role_assignment" "e2e_foundry_reader" {
  scope                = var.foundry_project_id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.e2e.principal_id
}

// =====================================================================
// R2: Container Apps (placeholder - requires actual container images)
// =====================================================================
// Note: Container Apps and Job resources are commented out until container images
// exist. Uncomment after L2 lands the orchestrator/worker/e2e container images.

/*
resource "azurerm_container_app" "orchestrator" {
  name                         = "orchestrator"
  resource_group_name          = var.resource_group_name
  container_app_environment_id = module.managed_environment.resource_id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.orchestrator.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.orchestrator.id
  }

  ingress {
    external_enabled = false
    target_port      = 8000
    transport        = "http"
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "orchestrator"
      image  = "${var.acr_login_server}/orchestrator:${var.env_name}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "SERVICE_BUS_FQDN"
        value = local.service_bus_fqdn
      }
      env {
        name  = "SERVICE_BUS_QUEUE"
        value = var.service_bus_queue_name
      }
      env {
        name  = "STORAGE_QUEUE_ENDPOINT"
        value = var.storage_queue_endpoint
      }
      env {
        name  = "STORAGE_QUEUE_NAME"
        value = var.storage_queue_name
      }
      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.orchestrator.client_id
      }
      env {
        name  = "APIM_GATEWAY_URL"
        value = var.apim_gateway_url
      }
      env {
        name        = "APIM_SUBSCRIPTION_KEY"
        secret_name = "apim-subscription-key"
      }
      env {
        name  = "FOUNDRY_PROJECT_ENDPOINT"
        value = var.foundry_project_endpoint
      }
      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = var.application_insights_connection_string
      }
    }
  }

  secret {
    name  = "apim-subscription-key"
    value = "placeholder-to-be-overridden-by-keyvault"
  }
}
*/

// =====================================================================
// R3: E2E Container Apps Job (in-spoke testing)
// =====================================================================
resource "azurerm_container_app_job" "e2e_runner" {
  name                         = "e2e-runner"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  container_app_environment_id = module.managed_environment.resource_id
  workload_profile_name        = "Consumption"
  replica_timeout_in_seconds   = 1800
  replica_retry_limit          = 0
  tags                         = var.tags

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.e2e.id]
  }

  registry {
    server   = var.acr_login_server
    identity = azurerm_user_assigned_identity.e2e.id
  }

  template {
    container {
      name   = "e2e"
      image  = "mcr.microsoft.com/azurelinux/base/python:3.13"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.e2e.client_id
      }
      env {
        name  = "APIM_GATEWAY_URL"
        value = var.apim_gateway_url
      }
      env {
        name  = "LOG_ANALYTICS_WORKSPACE_ID"
        value = var.log_analytics_workspace_id
      }
      env {
        name  = "SERVICE_BUS_FQDN"
        value = local.service_bus_fqdn
      }
      env {
        name  = "SERVICE_BUS_QUEUE"
        value = var.service_bus_queue_name
      }
      env {
        name  = "STORAGE_QUEUE_ENDPOINT"
        value = var.storage_queue_endpoint
      }
      env {
        name  = "STORAGE_QUEUE_NAME"
        value = var.storage_queue_name
      }
      env {
        name  = "FOUNDRY_PROJECT_ENDPOINT"
        value = var.foundry_project_endpoint
      }
      env {
        name  = "ENV"
        value = var.env_name
      }
    }
  }
}

// =====================================================================
// Outputs
// =====================================================================

output "container_apps_env_id" {
  value = module.managed_environment.resource_id
}

output "container_apps_env_name" {
  value = module.managed_environment.name
}

output "container_apps_env_default_domain" {
  value = module.managed_environment.default_domain
}

// R2: CONTRACT.md outputs
output "orchestrator_uami_client_id" {
  value       = azurerm_user_assigned_identity.orchestrator.client_id
  description = "Orchestrator runtime UAMI client ID (for DefaultAzureCredential via AZURE_CLIENT_ID env var)."
}

output "worker_uami_client_id" {
  value       = azurerm_user_assigned_identity.worker.client_id
  description = "Worker runtime UAMI client ID (for DefaultAzureCredential via AZURE_CLIENT_ID env var)."
}

output "orchestrator_app_url" {
  value       = "placeholder.internal.azurecontainerapps.io"
  description = "Internal FQDN of orchestrator container app (placeholder until Container App provisioned)."
}

output "worker_app_name" {
  value = "worker"
}

output "e2e_job_name" {
  value       = azurerm_container_app_job.e2e_runner.name
  description = "E2E Container Apps Job name."
}

output "e2e_job_resource_group" {
  value       = var.resource_group_name
  description = "E2E Container Apps Job resource group."
}

output "e2e_uami_client_id" {
  value       = azurerm_user_assigned_identity.e2e.client_id
  description = "E2E runtime UAMI client ID (for DefaultAzureCredential via AZURE_CLIENT_ID env var)."
}

output "e2e_uami_resource_id" {
  value       = azurerm_user_assigned_identity.e2e.id
  description = "E2E runtime UAMI resource ID."
}
