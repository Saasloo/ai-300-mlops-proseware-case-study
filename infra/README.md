# Quick start


1. In the CLI, login to your azure account and select the right subscription
`az login` -> then follow the steps from the CLI

## Azure/Bicep MCP server

This repo has an `azure-bicep` MCP server configured in `.mcp.json` (Microsoft's official `@azure/mcp`), which gives Claude Code tools for Bicep schema lookup and Azure resource operations.

Prerequisites:
- [`fnm`](https://github.com/Node-JS-Version-Manager/fnm) installed, with Node 22 available (`fnm install 22`) — the server requires Node >=22
- `az login` completed (step 1 above)

Claude Code will pick up the server automatically when you open this project (you may be prompted to approve it on first use).

## Deploying

```
az deployment sub create \
  --location eastus2 \
  --template-file infra/main.bicep \
  --parameters secretsOfficerPrincipalId=$(az ad signed-in-user show --query id -o tsv)
```

## Smoke tests

After deploying, `infra/smoke-tests/` has scripts that confirm access to the deployed resources works end-to-end:

```
infra/smoke-tests/smoke-test-storage.sh
infra/smoke-tests/smoke-test-keyvault.sh
infra/smoke-tests/smoke-test-loganalytics.sh
infra/smoke-tests/smoke-test-appinsights.sh
```

All read the resource group from `$RESOURCE_GROUP` (defaults to `rg-proseware-dev`) and clean up after themselves. The Log Analytics one is read-only (no diagnostic settings are wired up yet), so it just confirms the workspace exists and its query endpoint responds. The Application Insights one is also read-only — it confirms the resource is provisioned and linked to the Log Analytics workspace.

## Tearing down (stop being charged)

Everything currently deployed here (Storage Account, Key Vault, Log Analytics workspace, Application Insights) is pay-as-you-go with no always-on compute, so idle cost is low — but not zero, and it grows once compute-backed resources (e.g. the Azure ML online endpoint from ADR 0005) land. When you're done for the day, delete the whole resource group rather than trying to pause individual resources:

Key Vault names in this repo are deterministic (derived from the resource group id, see `infra/keyvault.bicep`), and Key Vault has soft-delete enabled — so deleting the resource group alone leaves the vault name reserved in a soft-deleted state for 7 days. Redeploying before then will fail with a naming conflict. Always purge it as part of teardown:

```
KEYVAULT_NAME=$(az keyvault list --resource-group rg-proseware-dev --query "[0].name" -o tsv)
az group delete --name rg-proseware-dev --yes
az keyvault purge --name "$KEYVAULT_NAME" --location eastus2
```

This deletes every resource in the group and immediately frees the vault name. Notes:
- Purging is destructive — any secrets stored in the vault are gone for good. There's no way to recover them; if you need them again, you'll re-add them after the next deploy.
- Recreate everything later with the same `az deployment sub create` command from [Deploying](#deploying) above — it's idempotent since the resource group name and region are fixed, and will produce the same Key Vault name.
- If you only want to pause future work without deleting anything (e.g. mid-week), there's nothing to "stop" yet — none of the current resources bill for idle compute. This section will matter most once the AML online endpoint (ADR 0005) is deployed, since managed online endpoints bill for their allocated instances whether or not they're serving traffic.
