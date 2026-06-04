# Foundry API Type Migration Follow-up (Hub→AIServices)

**Context:** Citadel-v1 upstream uses `Microsoft.CognitiveServices/accounts@2026-01-15-preview` kind=AIServices (endpoint: `https://<name>.services.ai.azure.com`). Our Repo A foundry module uses `Microsoft.MachineLearningServices/workspaces@2024-10-01-preview` kind=Hub (endpoint: `https://<name>.api.azureml.ms`).

**Impact:** Endpoint format differs. APIM backend routing in Citadel gateway expects `services.ai.azure.com` format. Current Hub/Project endpoints may not match upstream behavior.

**Risk:** Breaking change — existing workloads pointing to `api.azureml.ms` endpoints would need reconfiguration. May require data-plane migration (projects, deployments, connections).

**Recommendation:** Assess before migrating:
1. Test Citadel gateway with current Hub/Project endpoints (verify APIM backend routing works or requires path rewrites)
2. If routing succeeds → defer migration (functional equivalence achieved)
3. If routing fails → stage migration with clear runbook for endpoint cutover

**PR Scope:** This follow-up PR would:
- Replace `azapi_resource` Hub/Project (MachineLearningServices) with CognitiveServices/accounts kind=AIServices + child projects
- Update `project_endpoint` output format to `services.ai.azure.com` path
- Add migration guide for existing deployments

**Status:** Deferred pending functional validation. Steps 10+11 (Pass 3) add networkInjections + App Insights connection to existing Hub/Project module to unblock Citadel integration without breaking changes.

**Source:** Azure-Samples/ai-hub-gateway-solution-accelerator @ citadel-v1, bicep/infra/modules/foundry/foundry.bicep lines 53-68 (CognitiveServices resource type)
