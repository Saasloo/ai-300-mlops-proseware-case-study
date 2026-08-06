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
