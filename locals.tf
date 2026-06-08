locals {
  name_suffix = "${var.name_prefix}-${var.environment}-${var.location}"

  rg_network  = coalesce(try(var.resource_group_names.network, null), "rg-${local.name_suffix}-network")
  rg_platform = coalesce(try(var.resource_group_names.platform, null), "rg-${local.name_suffix}-platform")
  rg_gateway  = coalesce(try(var.resource_group_names.gateway, null), "rg-${local.name_suffix}-gateway")
  rg_compute  = coalesce(try(var.resource_group_names.compute, null), "rg-${local.name_suffix}-compute")

  sku_map = {
    dev  = { search = "standard", acr = "Premium" }
    test = { search = "standard", acr = "Premium" }
    prod = { search = "standard2", acr = "Premium" }
  }
  sku = local.sku_map[var.environment]

  apim_sku   = var.environment == "prod" ? "Premium_2" : "Developer_1"
  apim_zones = var.environment == "prod" ? ["1", "2", "3"] : []

  tags = merge(
    var.tags,
    { environment = var.environment },
    var.network_group_tag == null ? {} : { network-group = var.network_group_tag },
  )
  deployer_uami_tag = try(local.tags.deployerUami, null)
  canonical_deployer_uami_tag = local.deployer_uami_tag == null ? null : replace(
    replace(local.deployer_uami_tag, "/resourcegroups/", "/resourceGroups/"),
    "/providers/microsoft.managedidentity/userassignedidentities/",
    "/providers/Microsoft.ManagedIdentity/userAssignedIdentities/"
  )
  gateway_tags = local.canonical_deployer_uami_tag == null ? local.tags : merge(local.tags, {
    deployerUami = local.canonical_deployer_uami_tag
  })
}
