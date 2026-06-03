# Network egress requirements

These egress FQDNs must be opened at the hub Azure Firewall for force-tunneled spokes; canonical source: alz-firewall-ops/FIREWALL-EGRESS-IMPLEMENTED.md.

Scope: private-by-default AI Foundry Citadel spokes where public network access is disabled for data services and only residual AI portal/control-plane/model-artifact egress leaves through the hub firewall.

| FQDN | Port/proto | Why | Originally missed? |
|---|---|---|---|
| `ai.azure.com` | TCP 443 | Azure AI Foundry portal and project UX callbacks. | Yes |
| `*.ai.azure.com` | TCP 443 | AI Foundry regional/subdomain portal endpoints. | Yes |
| `*.services.ai.azure.com` | TCP 443 | AI Foundry service APIs used during project/agent bootstrap. | Yes |
| `*.openai.azure.com` | TCP 443 | Azure OpenAI data-plane endpoint for model inference and deployments. | Yes |
| `*.cognitiveservices.azure.com` | TCP 443 | Cognitive Services/AOAI control and data-plane endpoints. | Yes |
| `*.search.windows.net` | TCP 443 | Azure AI Search control/data-plane endpoint used by Foundry patterns. | Yes |
| `*.azureml.ms` | TCP 443 | Foundry/Azure ML portal callback endpoints during agent service bootstrap. | Yes |
| `*.api.azureml.ms` | TCP 443 | Foundry/Azure ML API callback endpoints during agent service bootstrap. | Yes |
| `*.blob.core.windows.net` | TCP 443 | Model artifacts and storage-backed data plane, including PE-backed services that still expose blob FQDNs. | Yes |
| `openaipublic.blob.core.windows.net` | TCP 443 | Public OpenAI model artifact downloads on first deployment. | Yes |
| `management.azure.com` | TCP 443 | Azure Resource Manager control-plane operations from deployment/runtime automation. | No |
| `login.microsoftonline.com` | TCP 443 | Entra ID authentication and managed identity token acquisition. | No |
| `*.login.microsoftonline.com` | TCP 443 | Regional Entra ID endpoints. | No |
| `*.login.microsoft.com` | TCP 443 | Entra login redirects. | No |
| `login.microsoft.com` | TCP 443 | Entra login redirect. | No |
| `graph.microsoft.com` | TCP 443 | Microsoft Graph identity/group lookups used by providers and identity flows. | No |
| `*.identity.azure.net` | TCP 443 | Managed identity endpoint/proxy path for Azure-hosted workloads. | No |

## Notes

- Private endpoints and Private DNS remain the primary path for Foundry, AOAI, Search, Storage, Key Vault, Cosmos DB, and ACR where the module provisions them.
- The FQDN rules above cover residual public control-plane, portal callback, and model-artifact paths that private endpoints do not satisfy.
