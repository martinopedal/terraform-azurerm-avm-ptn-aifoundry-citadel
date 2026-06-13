# Architecture Decision: Citadel Dev Gateway -> Prod AOAI Backend

**Status:** Implemented (codified 2026-06-10)  
**Context:** Citadel E2E validation  
**Decision owner:** @martinopedal

## Context

The Citadel AI Hub Gateway APIM (`apim-citadel-dev-swc`) is deployed in a "dev" environment (VNet `vnet-foundry-dev`, resource group `rg-demo-citadel-aigateway`). The Foundry AI platform was initially deployed with only a "prod" environment - only `aoai-foundry-prod-swedencentral` exists in `rg-foundry-prod-swedencentral-platform`.

During E2E validation (2026-06-10), the APIM `aoai-api` was configured to route to the prod AOAI backend because no dev AOAI backend exists.

## Decision

**Target backend for Citadel dev gateway: PROD AOAI (`aoai-foundry-prod-swedencentral`)**

The `aoai-api` API policy in `modules/gateway/main.tf` uses `var.aoai_endpoint`, which the consumer (`dnb-foundry-agent-demo`) wires to the prod AOAI endpoint.

Rationale:
1. **Network path works**: The dev-vnet APIM can reach the prod AOAI private endpoint (10.50.1.11) via spoke-to-spoke connectivity. The E2E test succeeded with HTTP 200.
2. **Cost efficiency**: Running a separate dev AOAI account with duplicate model deployments (gpt-4o @ 120K TPM, text-embedding-3-large @ 50K TPM) would double AOAI spend (~$150-300/mo per environment).
3. **Low blast radius**: The dev gateway has limited traffic (internal testing, E2E validation). Production workloads do not flow through the dev gateway.

## Consequences

**Accepted:**
- The "dev" Citadel gateway is not fully isolated - it shares the prod AOAI backend.
- Dev gateway failures or misconfigurations could theoretically impact prod AOAI quota/rate limits (mitigated by low dev traffic).

**Monitoring:**
- AOAI request metrics (`AzureDiagnostics` logs) should tag requests by source APIM to distinguish dev vs prod gateway traffic.
- If dev traffic grows or prod isolation becomes critical, deploy a separate dev AOAI account.

## Future Clean-Separation Option

Deploy a full dev Foundry environment (`rg-foundry-dev-swedencentral-platform`) with:
- `aoai-foundry-dev-swedencentral` (gpt-4o + text-embedding-3-large deployments)
- `hub-foundry-dev-swedencentral` + `proj-foundry-dev-swedencentral`
- ACR, Storage, Cosmos, etc. (dev-scoped)

This would provide full environment isolation at ~2x infrastructure cost.

## References

- Live fix: `.squad/decisions/inbox/squad-citadel-e2e-green.md` (2026-06-10)
- Consumer wiring: `dnb-foundry-agent-demo/infra/terraform/platform/main.tf` (Citadel module call)
- Codified policy: `modules/gateway/main.tf` (azurerm_api_management_api_policy.aoai_api)
