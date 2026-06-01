# Terraform AVM pattern: AI Foundry Citadel

This module deploys a private-by-default Azure AI Foundry "Citadel" landing-zone pattern:

- Azure AI Foundry hub and project using AzAPI (`Microsoft.MachineLearningServices/workspaces@2024-10-01-preview`)
- Azure OpenAI account and deployments
- API Management gateway in classic internal VNet mode (`Developer_1` for non-prod, `Premium_2` with zones for prod)
- Azure Container Apps managed environment and e2e job
- Azure AI Search, Cosmos DB, Key Vault, Azure Container Registry, and a StorageV2 account with blob, file, and queue private endpoints
- Spoke VNet, NSGs, and carved subnets for APIM, ACA, private endpoints, App Gateway, and integration
- Log Analytics workspace and Application Insights

The module does **not** create hub Private DNS zones, hub peering, Azure Policy, AVNM configuration, or broad RBAC/governance assignments. Consumers provide existing Private DNS zone IDs and handle platform governance outside this module.

## Naming/provider rationale

Repository name: `terraform-azurerm-avm-ptn-aifoundry-citadel`.

Although the Foundry hub/project and some preview child resources stay on AzAPI, the pattern is mostly composed from Azure Verified Modules in the `azurerm` ecosystem. The Terraform Registry provider segment is therefore `azurerm`.

## Architecture

```mermaid
flowchart LR
  Hub[Hub VNet + Private DNS zones] --> Spoke[VNet spoke]
  Spoke --> APIM[APIM internal gateway]
  Spoke --> ACA[Container Apps Environment]
  Spoke --> PE[Private Endpoint subnet]
  PE --> AOAI[Azure OpenAI]
  PE --> Foundry[AI Foundry hub/project]
  PE --> Search[AI Search]
  PE --> Cosmos[Cosmos DB]
  PE --> Storage[Storage blob/file/queue]
  PE --> KV[Key Vault]
  PE --> ACR[Container Registry]
  ACA --> APIM
  APIM --> AOAI
  APIM --> Foundry
```

## Usage

```hcl
module "citadel" {
  source = "github.com/martinopedal/terraform-azurerm-avm-ptn-aifoundry-citadel?ref=v0.1.0"

  name_prefix         = "citadel"
  environment         = "dev"
  location            = "swedencentral"
  spoke_address_space = "10.16.4.0/24"

  private_dns_zone_ids = {
    "privatelink.api.azureml.ms"         = azurerm_private_dns_zone.api_azureml.id
    "privatelink.azurecr.io"             = azurerm_private_dns_zone.acr.id
    "privatelink.blob.core.windows.net"  = azurerm_private_dns_zone.blob.id
    "privatelink.documents.azure.com"    = azurerm_private_dns_zone.cosmos.id
    "privatelink.file.core.windows.net"  = azurerm_private_dns_zone.file.id
    "privatelink.notebooks.azure.net"    = azurerm_private_dns_zone.notebooks.id
    "privatelink.openai.azure.com"       = azurerm_private_dns_zone.openai.id
    "privatelink.queue.core.windows.net" = azurerm_private_dns_zone.queue.id
    "privatelink.search.windows.net"     = azurerm_private_dns_zone.search.id
    "privatelink.vaultcore.azure.net"    = azurerm_private_dns_zone.vault.id
  }

  tags = {
    workload  = "aifoundry"
    managedBy = "terraform"
  }
}
```

See `examples/default` for a complete syntactic example.

## Inputs

| Name | Type | Default | Description |
|---|---:|---:|---|
| `environment` | `string` | `"dev"` | Environment name: `dev`, `test`, or `prod`. Drives APIM and service SKUs. |
| `location` | `string` | `"swedencentral"` | Azure region. |
| `name_prefix` | `string` | `"citadel"` | Short prefix for resource names. |
| `resource_group_names` | `object` | `{}` | Optional names for network/platform/gateway/compute resource groups. |
| `spoke_address_space` | `string` | `"10.16.4.0/24"` | Spoke CIDR carved into APIM, ACA, PE, AGW, and integration subnets. |
| `hub_vnet_resource_id` | `string` | `null` | Optional hub VNet ID for external coordination. No peering is created by this module. |
| `private_dns_zone_ids` | `map(string)` | n/a | Existing hub-managed Private DNS zones keyed by zone name. |
| `tags` | `map(string)` | `{}` | Tags applied to resources. |
| `network_group_tag` | `string` | `null` | Optional `network-group` tag value for tag-driven AVNM membership. |
| `enable_telemetry` | `bool` | `true` | Passed to all consumed AVM modules. |
| `git_sha` | `string` | `"latest"` | Placeholder container image tag. |

## Outputs

Key outputs include resource group names, VNet/subnet IDs, data-plane resource IDs, Storage Queue endpoint/name, Azure OpenAI endpoint, Foundry project endpoint, APIM gateway URL and principal ID, ACA environment ID, and runtime UAMI client IDs.

## AVM modules consumed

| Area | AVM module | Version |
|---|---|---:|
| VNet/subnets | `Azure/avm-res-network-virtualnetwork/azurerm` | `0.17.1` |
| Private endpoint (Foundry hub) | `Azure/avm-res-network-privateendpoint/azurerm` | `0.2.0` |
| Key Vault | `Azure/avm-res-keyvault-vault/azurerm` | `0.10.2` |
| Storage account + blob/file/queue PEs | `Azure/avm-res-storage-storageaccount/azurerm` | `0.7.2` |
| Container Registry | `Azure/avm-res-containerregistry-registry/azurerm` | `0.5.1` |
| Cosmos DB | `Azure/avm-res-documentdb-databaseaccount/azurerm` | `0.10.0` |
| AI Search | `Azure/avm-res-search-searchservice/azurerm` | `0.2.0` |
| Log Analytics | `Azure/avm-res-operationalinsights-workspace/azurerm` | `0.5.1` |
| Application Insights | `Azure/avm-res-insights-component/azurerm` | `0.4.0` |
| Azure OpenAI | `Azure/avm-res-cognitiveservices-account/azurerm` | `0.11.0` |
| API Management | `Azure/avm-res-apimanagement-service/azurerm` | `0.9.0` |
| Container Apps Environment | `Azure/avm-res-app-managedenvironment/azurerm` | `0.5.0` |

## AzAPI kept intentionally

- AI Foundry hub/project and project connection remain `azapi_resource` because the current azurerm and AVM surfaces do not expose the required hub/project `kind`, associated resource contract, and managed network settings.
- ACR agent pool remains AzAPI because the ACR AVM does not expose registry agent pools.

## License

MIT
