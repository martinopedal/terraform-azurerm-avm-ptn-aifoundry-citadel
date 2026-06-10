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
variable "aoai_resource_id" { type = string }
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

data "azurerm_client_config" "current" {}
locals {
  cognitive_services_user_role_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/a97b65f3-24c7-4388-baec-2e87135dc908"
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
  zones                     = length(var.zones) > 0 ? var.zones : null
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

resource "azurerm_role_assignment" "apim_to_aoai" {
  scope              = var.aoai_resource_id
  role_definition_id = local.cognitive_services_user_role_id
  principal_id       = module.apim.workspace_identity.principal_id
  principal_type     = "ServicePrincipal"
}

// =====================================================================
// APIM API: OpenAI proxy to Foundry AOAI backend
// =====================================================================
resource "azurerm_api_management_api" "aoai_api" {
  name                  = "aoai-api"
  resource_group_name   = var.resource_group_name
  api_management_name   = module.apim.name
  revision              = "1"
  display_name          = "Azure OpenAI API"
  path                  = "openai"
  protocols             = ["https"]
  subscription_required = true
  service_url           = null # Backend URL set via policy, not serviceUrl

  import {
    content_format = "openapi+json"
    content_value = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Azure OpenAI API"
        version = "1.0"
      }
      servers = [
        { url = "https://${module.apim.apim_gateway_url}/openai" }
      ]
      paths = {
        "/deployments/{deployment-id}/chat/completions" = {
          post = {
            operationId = "chatCompletions"
            summary     = "Creates a completion for the chat message"
            parameters = [
              {
                name     = "deployment-id"
                in       = "path"
                required = true
                schema   = { type = "string" }
              },
              {
                name     = "api-version"
                in       = "query"
                required = true
                schema   = { type = "string" }
              }
            ]
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = { type = "object" }
                }
              }
            }
            responses = {
              "200" = {
                description = "Success"
                content = {
                  "application/json" = {
                    schema = { type = "object" }
                  }
                }
              }
            }
          }
        }
      }
    })
  }
}

// =====================================================================
// APIM API Policy: Backend routing + Managed Identity auth
// Codifies the live fix from 2026-06-10 (squad-citadel-e2e-green.md)
// =====================================================================
resource "azurerm_api_management_api_policy" "aoai_api" {
  api_name            = azurerm_api_management_api.aoai_api.name
  api_management_name = module.apim.name
  resource_group_name = var.resource_group_name

  xml_content = <<XML
<policies>
  <inbound>
    <base />
    <!-- Route to the Foundry AOAI backend (prod until dev AOAI is deployed) -->
    <set-backend-service base-url="${var.aoai_endpoint}" />
    <!-- Authenticate via APIM system-assigned managed identity -->
    <authentication-managed-identity resource="https://cognitiveservices.azure.com" output-token-variable-name="msi-token" />
    <!-- Set Authorization header with the MI token -->
    <set-header name="Authorization" exists-action="override">
      <value>@("Bearer " + (string)context.Variables["msi-token"])</value>
    </set-header>
    <!-- Strip the client subscription key before forwarding to backend -->
    <set-header name="api-key" exists-action="delete" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

output "apim_name" { value = module.apim.name }
output "apim_id" { value = module.apim.resource_id }
output "apim_gateway_url" { value = module.apim.apim_gateway_url }
output "apim_principal_id" { value = module.apim.workspace_identity.principal_id }
